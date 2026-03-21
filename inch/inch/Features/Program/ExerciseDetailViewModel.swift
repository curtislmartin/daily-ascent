import Foundation
import SwiftData
import InchShared

@Observable
final class ExerciseDetailViewModel {
    var sessionHistory: [SessionSummary] = []
    var upcomingSchedule: [ProjectedDay] = []
    var testTarget: Int = 0
    var accentColorHex: String = ""

    private let engine = SchedulingEngine()

    func load(enrolmentId: PersistentIdentifier, context: ModelContext) {
        let enrolment: ExerciseEnrolment? = context.registeredModel(for: enrolmentId)
            ?? fetchEnrolment(enrolmentId, context: context)
        guard let enrolment,
              let def = enrolment.exerciseDefinition,
              let levelDef = def.levels?.first(where: { $0.level == enrolment.currentLevel })
        else { return }

        accentColorHex = def.color
        testTarget = levelDef.testTarget

        let exerciseId = def.exerciseId
        let descriptor = FetchDescriptor<CompletedSet>(
            predicate: #Predicate { $0.exerciseId == exerciseId },
            sortBy: [SortDescriptor(\.sessionDate)]
        )
        let allSets = (try? context.fetch(descriptor)) ?? []
        sessionHistory = groupIntoSessions(allSets)

        let enrolmentSnap = EnrolmentSnapshot(enrolment)
        let levelSnap = LevelSnapshot(levelDef)
        let daySnaps = (levelDef.days ?? []).map { DaySnapshot($0) }
        let startDate = enrolment.nextScheduledDate ?? Date.now
        upcomingSchedule = engine.projectSchedule(
            enrolment: enrolmentSnap,
            level: levelSnap,
            days: daySnaps,
            startDate: startDate
        )
    }

    // MARK: - Private

    private func groupIntoSessions(_ sets: [CompletedSet]) -> [SessionSummary] {
        var grouped: [Date: (reps: Int, isTest: Bool)] = [:]
        for set in sets {
            let day = Calendar.current.startOfDay(for: set.sessionDate)
            var entry = grouped[day] ?? (reps: 0, isTest: false)
            entry.reps += set.actualReps
            if set.isTest { entry.isTest = true }
            grouped[day] = entry
        }
        return grouped
            .map { SessionSummary(id: $0.key, date: $0.key, totalReps: $0.value.reps, isTest: $0.value.isTest) }
            .sorted { $0.date < $1.date }
    }

    private func fetchEnrolment(_ id: PersistentIdentifier, context: ModelContext) -> ExerciseEnrolment? {
        let all = (try? context.fetch(FetchDescriptor<ExerciseEnrolment>())) ?? []
        return all.first(where: { $0.persistentModelID == id })
    }
}
