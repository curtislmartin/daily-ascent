import Foundation
import SwiftData
import InchShared

@Observable
final class HistoryViewModel {

    // MARK: - Log

    func weekGroups(from sets: [CompletedSet]) -> [WeekGroup] {
        guard !sets.isEmpty else { return [] }
        let calendar = Calendar.current

        let byDay = Dictionary(grouping: sets) { calendar.startOfDay(for: $0.sessionDate) }
        let dayGroups = byDay.map { buildDayGroup(day: $0.key, sets: $0.value) }

        let byWeek = Dictionary(grouping: dayGroups) { dayGroup in
            calendar.dateInterval(of: .weekOfYear, for: dayGroup.id)?.start ?? dayGroup.id
        }

        return byWeek.map { weekStart, days in
            let sorted = days.sorted { $0.id > $1.id }
            return WeekGroup(
                id: weekStart,
                weekLabel: "Week of \(weekStart.formatted(.dateTime.day().month(.abbreviated)))",
                totalReps: days.reduce(0) { $0 + $1.totalReps },
                sessionCount: days.count,
                days: sorted
            )
        }.sorted { $0.id > $1.id }
    }

    private func buildDayGroup(day: Date, sets: [CompletedSet]) -> DayGroup {
        let byExercise = Dictionary(grouping: sets, by: \.exerciseId)
        let summaries = byExercise.values.compactMap { exerciseSets -> ExerciseSummary? in
            guard let first = exerciseSets.first else { return nil }
            let isTimed = first.countingMode == .timed
            let totalDuration = isTimed
                ? exerciseSets.compactMap(\.setDurationSeconds).reduce(0, +)
                : nil
            return ExerciseSummary(
                id: first.exerciseId,
                exerciseName: first.enrolment?.exerciseDefinition?.name ?? first.exerciseId,
                color: first.enrolment?.exerciseDefinition?.color ?? "",
                level: first.level,
                dayNumber: first.dayNumber,
                setCount: exerciseSets.count,
                actualReps: exerciseSets.reduce(0) { $0 + $1.actualReps },
                targetReps: exerciseSets.reduce(0) { $0 + $1.targetReps },
                isTest: first.isTest,
                testPassed: first.testPassed,
                enrolmentId: first.enrolment?.persistentModelID,
                countingMode: first.countingMode,
                totalDurationSeconds: totalDuration,
                targetDurationSeconds: first.targetDurationSeconds
            )
        }.sorted { $0.exerciseName < $1.exerciseName }

        let times = sets.map(\.completedAt)
        let duration: TimeInterval? = {
            guard let min = times.min(), let max = times.max(), max > min else { return nil }
            return max.timeIntervalSince(min)
        }()

        return DayGroup(
            id: day,
            exercises: summaries,
            totalReps: summaries.reduce(0) { $0 + $1.actualReps },
            duration: duration,
            isTestDay: sets.contains { $0.isTest }
        )
    }

    // MARK: - Stats

    func stats(from sets: [CompletedSet], enrolments: [ExerciseEnrolment]) -> HistoryStats {
        let calendar = Calendar.current
        let totalReps = sets.reduce(0) { $0 + $1.actualReps }
        let sessionCount = Set(sets.map { calendar.startOfDay(for: $0.sessionDate) }).count

        let byExercise = Dictionary(grouping: sets, by: \.exerciseId)
        let exerciseStats = byExercise.compactMap { exerciseId, exerciseSets -> ExerciseStat? in
            guard let first = exerciseSets.first else { return nil }
            let def = first.enrolment?.exerciseDefinition
            let enrolment = enrolments.first { $0.exerciseDefinition?.exerciseId == exerciseId }
            let level = enrolment?.currentLevel ?? first.level
            let totalDays = def?.levels?.first { $0.level == level }?.days?.count ?? 0
            return ExerciseStat(
                id: exerciseId,
                name: def?.name ?? exerciseId,
                color: def?.color ?? "",
                totalReps: exerciseSets.reduce(0) { $0 + $1.actualReps },
                currentLevel: level,
                currentDay: enrolment?.currentDay ?? first.dayNumber,
                totalDaysInLevel: totalDays,
                enrolmentId: enrolment?.persistentModelID
            )
        }.sorted { $0.totalReps > $1.totalReps }

        let today = calendar.startOfDay(for: .now)
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let daysTrainedThisWeek = Set(
            sets.filter { $0.sessionDate >= sevenDaysAgo }
                .map { calendar.startOfDay(for: $0.sessionDate) }
        ).count

        return HistoryStats(
            totalReps: totalReps,
            sessionCount: sessionCount,
            exerciseStats: exerciseStats,
            weeklyData: weeklyData(from: sets),
            daysTrainedThisWeek: daysTrainedThisWeek
        )
    }

    private func weeklyData(from sets: [CompletedSet]) -> [WeeklyData] {
        let calendar = Calendar.current
        let byWeek = Dictionary(grouping: sets) { set in
            calendar.dateInterval(of: .weekOfYear, for: set.sessionDate)?.start
                ?? calendar.startOfDay(for: set.sessionDate)
        }
        let allWeeks = byWeek.map { weekStart, weekSets -> WeeklyData in
            let byExercise = Dictionary(grouping: weekSets, by: \.exerciseId)
            let breakdown = byExercise.compactMap { exerciseId, exSets -> ExerciseWeekReps? in
                guard let first = exSets.first else { return nil }
                let def = first.enrolment?.exerciseDefinition
                return ExerciseWeekReps(
                    id: "\(weekStart.timeIntervalSince1970)-\(exerciseId)",
                    exerciseId: exerciseId,
                    name: def?.name ?? exerciseId,
                    color: def?.color ?? "",
                    totalReps: exSets.reduce(0) { $0 + $1.actualReps }
                )
            }
            return WeeklyData(id: weekStart, exerciseBreakdown: breakdown)
        }
        return Array(allWeeks.sorted { $0.id > $1.id }.prefix(8).reversed())
    }

    // MARK: - Types

    struct WeekGroup: Identifiable {
        let id: Date
        let weekLabel: String
        let totalReps: Int
        let sessionCount: Int
        let days: [DayGroup]
    }

    struct DayGroup: Identifiable {
        let id: Date
        let exercises: [ExerciseSummary]
        let totalReps: Int
        let duration: TimeInterval?
        let isTestDay: Bool
    }

    struct ExerciseSummary: Identifiable {
        let id: String
        let exerciseName: String
        let color: String
        let level: Int
        let dayNumber: Int
        let setCount: Int
        let actualReps: Int
        let targetReps: Int
        let isTest: Bool
        let testPassed: Bool?
        let enrolmentId: PersistentIdentifier?
        let countingMode: CountingMode
        let totalDurationSeconds: Double?
        let targetDurationSeconds: Int?
    }

    struct HistoryStats {
        let totalReps: Int
        let sessionCount: Int
        let exerciseStats: [ExerciseStat]
        let weeklyData: [WeeklyData]
        let daysTrainedThisWeek: Int
    }

    struct ExerciseStat: Identifiable {
        let id: String
        let name: String
        let color: String
        let totalReps: Int
        let currentLevel: Int
        let currentDay: Int
        let totalDaysInLevel: Int
        let enrolmentId: PersistentIdentifier?
    }

    struct WeeklyData: Identifiable {
        let id: Date
        let exerciseBreakdown: [ExerciseWeekReps]
    }

    struct ExerciseWeekReps: Identifiable {
        let id: String
        let exerciseId: String
        let name: String
        let color: String
        let totalReps: Int
    }
}
