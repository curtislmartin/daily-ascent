import Foundation
import WatchConnectivity
import SwiftData
import InchShared

@Observable
final class WatchConnectivityService: NSObject, WCSessionDelegate {
    private nonisolated static let validExerciseIds: Set<String> = [
        "push_ups", "squats", "sit_ups", "pull_ups", "glute_bridges", "dead_bugs"
    ]

    private var wcSession: WCSession?

    // let constants so nonisolated delegate methods can access them safely
    private let _completionReports: AsyncStream<WatchCompletionReport>.Continuation
    let completionReports: AsyncStream<WatchCompletionReport>

    private let _receivedFiles: AsyncStream<ReceivedSensorFile>.Continuation
    let receivedFiles: AsyncStream<ReceivedSensorFile>

    override init() {
        let (stream, continuation) = AsyncStream<WatchCompletionReport>.makeStream()
        completionReports = stream
        _completionReports = continuation
        let (filesStream, filesContinuation) = AsyncStream<ReceivedSensorFile>.makeStream()
        receivedFiles = filesStream
        _receivedFiles = filesContinuation
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        wcSession = WCSession.default
        wcSession?.delegate = self
        wcSession?.activate()
    }

    var isWatchReachable: Bool {
        wcSession?.isReachable ?? false
    }

    // MARK: - Sending

    func sendSchedule(_ sessions: [WatchSession]) {
        guard let wcSession, wcSession.activationState == .activated else { return }
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        try? wcSession.updateApplicationContext(["type": "schedule", "data": data])
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

    func sendRecordingStart(exerciseId: String, setNumber: Int, sessionId: String) {
        guard let wcSession, wcSession.isReachable else { return }
        wcSession.sendMessage(
            ["type": "recordingStart", "exerciseId": exerciseId, "setNumber": setNumber, "sessionId": sessionId],
            replyHandler: nil,
            errorHandler: nil
        )
    }

    func sendRecordingStop(exerciseId: String, setNumber: Int) {
        guard let wcSession, wcSession.isReachable else { return }
        wcSession.sendMessage(
            ["type": "recordingStop", "exerciseId": exerciseId, "setNumber": setNumber],
            replyHandler: nil,
            errorHandler: nil
        )
    }

    // MARK: - Debug

    /// Injects a synthetic completion report into the live stream.
    /// Only called from DebugViewModel in #if DEBUG builds.
    func simulateCompletionReport(_ report: WatchCompletionReport) {
        _completionReports.yield(report)
    }

    // MARK: - Receiving

    func handleCompletionReports(context: ModelContext) async {
        for await report in completionReports {
            applyReport(report, context: context)
        }
    }

    func handleReceivedFiles(context: ModelContext) async {
        for await received in receivedFiles {
            let meta = received.metadata
            let recording = SensorRecording(
                recordedAt: Date(timeIntervalSince1970: meta.recordedAt),
                device: .appleWatch,
                exerciseId: meta.exerciseId,
                level: meta.level,
                dayNumber: meta.dayNumber,
                setNumber: meta.setNumber,
                confirmedReps: meta.confirmedReps,
                sampleRateHz: meta.sampleRateHz,
                durationSeconds: meta.durationSeconds,
                countingMode: meta.countingMode,
                filePath: received.fileURL.path,
                fileSizeBytes: received.fileSizeBytes,
                sessionId: meta.sessionId
            )
            context.insert(recording)
            try? context.save()
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
        guard let raw = file.metadata,
              let exerciseId = raw["exerciseId"] as? String,
              !exerciseId.isEmpty,
              Self.validExerciseIds.contains(exerciseId)
        else { return }

        let destDir = URL.documentsDirectory.appending(path: "sensor_data", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        var dirForBackup = destDir
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try? dirForBackup.setResourceValues(resourceValues)

        let dest = destDir.appending(path: file.fileURL.lastPathComponent)
        try? FileManager.default.moveItem(at: file.fileURL, to: dest)

        let attrs = try? FileManager.default.attributesOfItem(atPath: dest.path(percentEncoded: false))
        let size = (attrs?[.size] as? Int) ?? 0
        guard size <= 5_000_000 else {
            try? FileManager.default.removeItem(at: dest)
            return
        }
        let meta = WatchSensorMetadata(
            exerciseId: exerciseId,
            setNumber: raw["setNumber"] as? Int ?? 0,
            device: raw["device"] as? String ?? SensorDevice.appleWatch.rawValue,
            level: raw["level"] as? Int ?? 0,
            dayNumber: raw["dayNumber"] as? Int ?? 0,
            confirmedReps: raw["confirmedReps"] as? Int ?? 0,
            durationSeconds: raw["durationSeconds"] as? Double ?? 0,
            countingMode: raw["countingMode"] as? String ?? "",
            sampleRateHz: raw["sampleRateHz"] as? Int ?? 50,
            recordedAt: raw["recordedAt"] as? Double ?? Date.now.timeIntervalSince1970,
            sessionId: raw["sessionId"] as? String ?? ""
        )
        _receivedFiles.yield(ReceivedSensorFile(fileURL: dest, metadata: meta, fileSizeBytes: size))
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        // Re-push the last known schedule so the watch gets it on activation
        if activationState == .activated,
           let existing = session.applicationContext["data"] {
            try? session.updateApplicationContext(["type": "schedule", "data": existing])
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
