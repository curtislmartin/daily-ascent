import Foundation
import SwiftData
import InchShared

enum WorkoutPhase: Equatable {
    case loading
    case ready
    case inSet(startedAt: Date)
    case confirming(targetReps: Int, duration: Double)
    case resting(restSeconds: Int)
    case complete
}

@Observable
final class WorkoutViewModel {
    private let enrolmentId: PersistentIdentifier

    var phase: WorkoutPhase = .loading
    var currentSetIndex: Int = 0
    var enrolment: ExerciseEnrolment?
    var prescription: DayPrescription?

    private var sessionDate: Date = .now
    var sessionTotalReps: Int = 0
    private let scheduler = SchedulingEngine()

    var exerciseName: String { enrolment?.exerciseDefinition?.name ?? "" }
    var accentColorHex: String { enrolment?.exerciseDefinition?.color ?? "" }
    var countingMode: CountingMode { enrolment?.exerciseDefinition?.countingMode ?? .postSetConfirmation }
    var restSeconds: Int { enrolment?.exerciseDefinition?.defaultRestSeconds ?? 60 }
    var currentTargetReps: Int { prescription?.sets[safe: currentSetIndex] ?? 0 }
    var totalSets: Int { prescription?.sets.count ?? 0 }
    var isTestDay: Bool { prescription?.isTest ?? false }

    init(enrolmentId: PersistentIdentifier) {
        self.enrolmentId = enrolmentId
    }

    func load(context: ModelContext) {
        let enrolment: ExerciseEnrolment? = context.registeredModel(for: enrolmentId)
            ?? fetchEnrolment(context: context)
        guard let enrolment else { return }
        self.enrolment = enrolment
        self.prescription = currentPrescription(for: enrolment)
        sessionDate = .now
        phase = .ready
    }

    func startSet() {
        phase = .inSet(startedAt: .now)
    }

    func endSet() {
        guard case .inSet(let startedAt) = phase else { return }
        let duration = Date.now.timeIntervalSince(startedAt)
        phase = .confirming(targetReps: currentTargetReps, duration: duration)
    }

    func confirmSet(actual: Int, context: ModelContext) {
        saveSet(actualReps: actual, context: context)
        advanceAfterSet(context: context)
    }

    func completeRealTimeSet(actual: Int, context: ModelContext) {
        saveSet(actualReps: actual, context: context)
        advanceAfterSet(context: context)
    }

    func finishRest() {
        phase = .ready
    }

    // MARK: - Private

    private func advanceAfterSet(context: ModelContext) {
        let nextIndex = currentSetIndex + 1
        if nextIndex >= totalSets {
            completeSession(context: context)
        } else {
            currentSetIndex = nextIndex
            phase = .resting(restSeconds: restSeconds)
        }
    }

    private func saveSet(actualReps: Int, context: ModelContext) {
        guard let enrolment, let prescription, let def = enrolment.exerciseDefinition else { return }
        let completedSet = CompletedSet(
            sessionDate: sessionDate,
            exerciseId: def.exerciseId,
            level: enrolment.currentLevel,
            dayNumber: enrolment.currentDay,
            setNumber: currentSetIndex + 1,
            targetReps: currentTargetReps,
            actualReps: actualReps,
            isTest: prescription.isTest,
            countingMode: countingMode
        )
        completedSet.enrolment = enrolment
        context.insert(completedSet)
        sessionTotalReps += actualReps
        try? context.save()
    }

    private func completeSession(context: ModelContext) {
        guard let enrolment,
              let def = enrolment.exerciseDefinition,
              let levelDef = def.levels?.first(where: { $0.level == enrolment.currentLevel })
        else { return }

        let snapshot = EnrolmentSnapshot(enrolment)
        let levelSnap = LevelSnapshot(levelDef)
        let updated = scheduler.applyCompletion(
            to: snapshot,
            level: levelSnap,
            actualDate: sessionDate,
            totalReps: sessionTotalReps
        )
        let nextDate = scheduler.computeNextDate(enrolment: updated, level: levelSnap)
        scheduler.writeBack(updated, to: enrolment, nextDate: nextDate)
        try? context.save()
        phase = .complete
    }

    private func currentPrescription(for enrolment: ExerciseEnrolment) -> DayPrescription? {
        enrolment.exerciseDefinition?
            .levels?
            .first(where: { $0.level == enrolment.currentLevel })?
            .days?
            .first(where: { $0.dayNumber == enrolment.currentDay })
    }

    private func fetchEnrolment(context: ModelContext) -> ExerciseEnrolment? {
        let all = (try? context.fetch(FetchDescriptor<ExerciseEnrolment>())) ?? []
        return all.first(where: { $0.persistentModelID == enrolmentId })
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
