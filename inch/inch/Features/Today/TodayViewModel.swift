import SwiftData
import Foundation
import InchShared

@Observable
final class TodayViewModel {
    var dueExercises: [ExerciseEnrolment] = []
    var completedTodayIds: Set<String> = []
    var isRestDay: Bool = false
    var conflictWarnings: [String: String] = [:]
    var nextTrainingDate: Date? = nil
    var nextTrainingCount: Int = 0
    private let detector = ConflictDetector()

    func loadToday(context: ModelContext, showWarnings: Bool = true) {
        let today = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
        let descriptor = FetchDescriptor<ExerciseEnrolment>(
            predicate: #Predicate { $0.isActive }
        )
        let all = (try? context.fetch(descriptor)) ?? []

        // Exercises due today (scheduled today or overdue)
        let dueToday = all.filter { enrolment in
            guard let scheduled = enrolment.nextScheduledDate else { return false }
            return Calendar.current.startOfDay(for: scheduled) <= today
        }

        // Exercises completed today (may have advanced nextScheduledDate)
        let setsDescriptor = FetchDescriptor<CompletedSet>(
            predicate: #Predicate { $0.sessionDate >= today && $0.sessionDate < tomorrow }
        )
        let todaySets = (try? context.fetch(setsDescriptor)) ?? []

        // Group today's sets by exercise ID
        let setsByExercise = Dictionary(grouping: todaySets, by: \.exerciseId)

        // An exercise is fully complete when all prescribed sets are done
        let fullyCompletedIds = Set(all.compactMap { enrolment -> String? in
            guard let id = enrolment.exerciseDefinition?.exerciseId else { return nil }
            let completedCount = setsByExercise[id]?.count ?? 0
            let prescribedCount = currentPrescription(for: enrolment)?.sets.count ?? 0
            guard prescribedCount > 0, completedCount >= prescribedCount else { return nil }
            return id
        })

        completedTodayIds = fullyCompletedIds

        // Include completed-today exercises that are no longer in the due list
        let completedEnrolments = all.filter { enrolment in
            guard let id = enrolment.exerciseDefinition?.exerciseId else { return false }
            return fullyCompletedIds.contains(id) && !dueToday.contains(where: { $0.persistentModelID == enrolment.persistentModelID })
        }

        dueExercises = dueToday + completedEnrolments
        isRestDay = dueExercises.isEmpty

        if isRestDay {
            computeNextTraining(from: all, after: today)
        }

        if showWarnings {
            detectConflictsForToday()
        } else {
            conflictWarnings = [:]
        }
        resetStreakForMissedDayIfNeeded(context: context, today: today)
    }

    private func computeNextTraining(from all: [ExerciseEnrolment], after today: Date) {
        let futureDates = all.compactMap(\.nextScheduledDate)
            .map { Calendar.current.startOfDay(for: $0) }
            .filter { $0 > today }
        guard let nearest = futureDates.min() else { return }
        nextTrainingDate = nearest
        nextTrainingCount = all.filter { enrolment in
            guard let d = enrolment.nextScheduledDate else { return false }
            return Calendar.current.startOfDay(for: d) == nearest
        }.count
    }

    private func detectConflictsForToday() {
        conflictWarnings = [:]
        let sessions: [ProjectedSession] = dueExercises.compactMap { enrolment in
            guard let def = enrolment.exerciseDefinition else { return nil }
            let isTest = currentPrescription(for: enrolment)?.isTest ?? false
            return ProjectedSession(
                exerciseId: def.exerciseId,
                muscleGroup: def.muscleGroup,
                isTest: isTest,
                date: .now,
                enrolmentId: def.exerciseId
            )
        }
        let conflicts = detector.detectConflicts(in: sessions)
        for conflict in conflicts {
            switch conflict {
            case .doubleTest(_, let ids):
                for id in ids {
                    conflictWarnings[id] = "Two test days scheduled today"
                }
            case .testWithSameGroupTraining(_, _, let trainingId):
                conflictWarnings[trainingId] = "Same muscle group as today's test"
            }
        }
    }

    private func resetStreakForMissedDayIfNeeded(context: ModelContext, today: Date) {
        guard !isRestDay else { return }
        let streaks = (try? context.fetch(FetchDescriptor<StreakState>())) ?? []
        guard let streakState = streaks.first, streakState.currentStreak > 0 else { return }
        guard let lastActive = streakState.lastActiveDate else { return }

        let lastDay = Calendar.current.startOfDay(for: lastActive)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today
        if lastDay < Calendar.current.startOfDay(for: yesterday) {
            streakState.currentStreak = 0
            try? context.save()
        }
    }

    func currentPrescription(for enrolment: ExerciseEnrolment) -> DayPrescription? {
        enrolment.exerciseDefinition?
            .levels?
            .first(where: { $0.level == enrolment.currentLevel })?
            .days?
            .first(where: { $0.dayNumber == enrolment.currentDay })
    }
}
