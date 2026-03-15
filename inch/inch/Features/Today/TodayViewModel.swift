import SwiftData
import Foundation
import InchShared

@Observable
final class TodayViewModel {
    var dueExercises: [ExerciseEnrolment] = []
    var isRestDay: Bool = false
    var conflictWarnings: [String: String] = [:]
    var nextTrainingDate: Date? = nil
    var nextTrainingCount: Int = 0

    private let detector = ConflictDetector()

    func loadToday(context: ModelContext, showWarnings: Bool = true) {
        let today = Calendar.current.startOfDay(for: .now)
        let descriptor = FetchDescriptor<ExerciseEnrolment>(
            predicate: #Predicate { $0.isActive }
        )
        let all = (try? context.fetch(descriptor)) ?? []

        dueExercises = all.filter { enrolment in
            guard let scheduled = enrolment.nextScheduledDate else { return false }
            return Calendar.current.startOfDay(for: scheduled) <= today
        }
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
