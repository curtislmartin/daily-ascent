import Foundation
import WatchConnectivity
import SwiftData
import InchShared

@Observable
final class WatchConnectivityService: NSObject, WCSessionDelegate {
    private var wcSession: WCSession?

    // let constants so nonisolated delegate methods can access them safely
    private let _completionReports: AsyncStream<WatchCompletionReport>.Continuation
    let completionReports: AsyncStream<WatchCompletionReport>

    override init() {
        let (stream, continuation) = AsyncStream<WatchCompletionReport>.makeStream()
        completionReports = stream
        _completionReports = continuation
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        wcSession = WCSession.default
        wcSession?.delegate = self
        wcSession?.activate()
    }

    // MARK: - Sending

    func sendSchedule(_ sessions: [WatchSession]) {
        guard let wcSession, wcSession.activationState == .activated else { return }
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        wcSession.transferUserInfo(["type": "schedule", "data": data])
    }

    func sendTodaySchedule(enrolments: [ExerciseEnrolment], settings: UserSettings?) {
        var sessions: [WatchSession] = []

        for enrolment in enrolments {
            guard let def = enrolment.exerciseDefinition,
                  let levelDef = def.levels?.first(where: { $0.level == enrolment.currentLevel }),
                  let prescription = levelDef.days?.first(where: { $0.dayNumber == enrolment.currentDay })
            else { continue }

            let restSeconds = settings?.restOverrides[def.exerciseId] ?? def.defaultRestSeconds
            let modeString: String
            if let override = settings?.countingModeOverrides[def.exerciseId] {
                modeString = override
            } else {
                modeString = def.countingMode.rawValue
            }

            sessions.append(WatchSession(
                exerciseId: def.exerciseId,
                exerciseName: def.name,
                color: def.color,
                level: enrolment.currentLevel,
                dayNumber: enrolment.currentDay,
                sets: prescription.sets,
                isTest: prescription.isTest,
                testTarget: prescription.isTest ? prescription.sets.first : nil,
                restSeconds: restSeconds,
                countingMode: modeString
            ))
        }

        sendSchedule(sessions)
    }

    // MARK: - Receiving

    func handleCompletionReports(context: ModelContext) async {
        for await report in completionReports {
            applyReport(report, context: context)
        }
    }

    private func applyReport(_ report: WatchCompletionReport, context: ModelContext) {
        let descriptor = FetchDescriptor<ExerciseEnrolment>(
            predicate: #Predicate { $0.isActive }
        )
        guard let enrolments = try? context.fetch(descriptor),
              let enrolment = enrolments.first(where: {
                  $0.exerciseDefinition?.exerciseId == report.exerciseId &&
                  $0.currentLevel == report.level &&
                  $0.currentDay == report.dayNumber
              }),
              let def = enrolment.exerciseDefinition,
              let levelDef = def.levels?.first(where: { $0.level == enrolment.currentLevel })
        else { return }

        let totalReps = report.completedSets.reduce(0) { $0 + $1.actualReps }
        let isTestDay = levelDef.days?.first(where: { $0.dayNumber == report.dayNumber })?.isTest ?? false
        let testPassed: Bool? = isTestDay ? (totalReps >= levelDef.testTarget) : nil

        for setResult in report.completedSets {
            let completed = CompletedSet(
                completedAt: report.completedAt,
                sessionDate: report.completedAt,
                exerciseId: report.exerciseId,
                level: report.level,
                dayNumber: report.dayNumber,
                setNumber: setResult.setNumber,
                targetReps: setResult.targetReps,
                actualReps: setResult.actualReps,
                isTest: isTestDay,
                testPassed: testPassed,
                setDurationSeconds: setResult.durationSeconds
            )
            completed.enrolment = enrolment
            context.insert(completed)
        }

        let engine = SchedulingEngine()
        let enrolmentSnap = EnrolmentSnapshot(enrolment)
        let levelSnap = LevelSnapshot(levelDef)
        let updated = engine.applyCompletion(
            to: enrolmentSnap,
            level: levelSnap,
            actualDate: report.completedAt,
            totalReps: totalReps
        )
        let nextDate = engine.computeNextDate(enrolment: updated, level: levelSnap)
        engine.writeBack(updated, to: enrolment, nextDate: nextDate)

        try? context.save()
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any]
    ) {
        guard let type = userInfo["type"] as? String,
              type == "completion",
              let data = userInfo["data"] as? Data,
              let report = try? JSONDecoder().decode(WatchCompletionReport.self, from: data)
        else { return }
        _completionReports.yield(report)
    }

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let destDir = URL.documentsDirectory.appending(path: "sensor_data", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        let dest = destDir.appending(path: file.fileURL.lastPathComponent)
        try? FileManager.default.moveItem(at: file.fileURL, to: dest)
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
