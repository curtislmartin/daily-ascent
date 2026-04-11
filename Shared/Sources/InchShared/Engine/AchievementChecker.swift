import Foundation
import SwiftData

public enum AchievementEvent {
    case workoutCompleted(exerciseId: String, totalReps: Int, level: Int, sessionDate: Date)
    case testPassed(exerciseId: String, level: Int, sessionDate: Date)
    case streakUpdated
    case programComplete
    case communityPercentileUpdated(exerciseId: String, level: Int, percentile: Int)
    case communityStreakPercentileUpdated(percentile: Int)
}

public struct AchievementChecker {
    public init() {}

    /// Evaluates achievement conditions against ModelContext.
    /// Returns newly unlocked Achievement values — NOT yet persisted.
    /// The call site is responsible for inserting them and saving context.
    /// Personal best achievements are returned with updated numericValue
    /// but NOT yet mutated in context — call site must update the existing record.
    public func check(after event: AchievementEvent, in context: ModelContext) -> [Achievement] {
        var unlocked: [Achievement] = []

        let existing = (try? context.fetch(FetchDescriptor<Achievement>())) ?? []
        let existingIds = Set(existing.map(\.id))

        switch event {
        case let .workoutCompleted(exerciseId, totalReps, level, sessionDate):
            if !existingIds.contains("first_workout") {
                unlocked.append(Achievement(
                    id: "first_workout", category: "milestone",
                    unlockedAt: .now, sessionDate: sessionDate
                ))
            }

            let totalSessions = completedSessionCount(in: context)
            for threshold in [5, 10, 25, 50, 100] {
                let id = "sessions_\(threshold)"
                if totalSessions >= threshold && !existingIds.contains(id) {
                    unlocked.append(Achievement(
                        id: id, category: "consistency",
                        unlockedAt: .now, sessionDate: sessionDate
                    ))
                }
            }

            let exerciseSessions = completedSessionCount(for: exerciseId, in: context)
            let exerciseCountId = "sessions_10_\(exerciseId)"
            if exerciseSessions >= 10 && !existingIds.contains(exerciseCountId) {
                unlocked.append(Achievement(
                    id: exerciseCountId, category: "consistency",
                    unlockedAt: .now, exerciseId: exerciseId, sessionDate: sessionDate
                ))
            }

            let pbId = "personal_best_\(exerciseId)"
            if let existingPB = existing.first(where: { $0.id == pbId }) {
                if totalReps > (existingPB.numericValue ?? 0) {
                    let updated = Achievement(
                        id: pbId, category: "performance",
                        unlockedAt: .now, exerciseId: exerciseId,
                        numericValue: totalReps, sessionDate: sessionDate
                    )
                    unlocked.append(updated)
                }
            } else if totalReps > 0 {
                unlocked.append(Achievement(
                    id: pbId, category: "performance",
                    unlockedAt: .now, exerciseId: exerciseId,
                    numericValue: totalReps, sessionDate: sessionDate
                ))
            }

            checkFullSet(existingIds: existingIds, sessionDate: sessionDate,
                        context: context, into: &unlocked)
            checkTimeOfDay(existingIds: existingIds, sessionDate: sessionDate,
                          context: context, into: &unlocked)
            checkHoliday(existingIds: existingIds, sessionDate: sessionDate, into: &unlocked)

        case let .testPassed(exerciseId, level, sessionDate):
            if !existingIds.contains("first_test") {
                unlocked.append(Achievement(
                    id: "first_test", category: "milestone",
                    unlockedAt: .now, sessionDate: sessionDate
                ))
            }
            let levelId = "level_complete_\(exerciseId)_l\(level)"
            if !existingIds.contains(levelId) {
                unlocked.append(Achievement(
                    id: levelId, category: "milestone",
                    unlockedAt: .now, exerciseId: exerciseId,
                    numericValue: level, sessionDate: sessionDate
                ))
            }
            checkTestGauntlet(existingIds: existingIds, newExercise: exerciseId,
                             context: context, sessionDate: sessionDate, into: &unlocked)
            checkProgramComplete(existingIds: existingIds, context: context,
                                sessionDate: sessionDate, into: &unlocked)

        case .streakUpdated:
            let streak = (try? context.fetch(FetchDescriptor<StreakState>()))?.first
            let current = streak?.currentStreak ?? 0
            for threshold in [3, 7, 14, 30, 60, 100] {
                let id = "streak_\(threshold)"
                if current >= threshold && !existingIds.contains(id) {
                    unlocked.append(Achievement(
                        id: id, category: "streak",
                        unlockedAt: .now, numericValue: current
                    ))
                }
            }

        case .programComplete:
            if !existingIds.contains("program_complete") {
                unlocked.append(Achievement(
                    id: "program_complete", category: "milestone", unlockedAt: .now
                ))
            }

        case let .communityPercentileUpdated(exerciseId, _, percentile):
            if percentile >= 50 && !existingIds.contains("community_top_half") {
                unlocked.append(Achievement(
                    id: "community_top_half", category: "community",
                    unlockedAt: .now, exerciseId: exerciseId
                ))
            }
            if percentile >= 75 && !existingIds.contains("community_upper_quarter") {
                unlocked.append(Achievement(
                    id: "community_upper_quarter", category: "community",
                    unlockedAt: .now, exerciseId: exerciseId
                ))
            }
            if percentile >= 90 && !existingIds.contains("community_top_10") {
                unlocked.append(Achievement(
                    id: "community_top_10", category: "community",
                    unlockedAt: .now, exerciseId: exerciseId
                ))
            }

        case let .communityStreakPercentileUpdated(percentile):
            if percentile >= 90 && !existingIds.contains("community_iron_streak") {
                unlocked.append(Achievement(
                    id: "community_iron_streak", category: "community",
                    unlockedAt: .now
                ))
            }
        }

        return unlocked
    }

    // MARK: - Private helpers

    private func completedSessionCount(in context: ModelContext) -> Int {
        let sets = (try? context.fetch(FetchDescriptor<CompletedSet>())) ?? []
        let dates = Set(sets.map { Calendar.current.startOfDay(for: $0.sessionDate) })
        return dates.count
    }

    private func completedSessionCount(for exerciseId: String, in context: ModelContext) -> Int {
        let sets = (try? context.fetch(FetchDescriptor<CompletedSet>())) ?? []
        let matching = sets.filter { $0.exerciseId == exerciseId }
        let dates = Set(matching.map { Calendar.current.startOfDay(for: $0.sessionDate) })
        return dates.count
    }

    private func checkFullSet(existingIds: Set<String>, sessionDate: Date,
                               context: ModelContext, into results: inout [Achievement]) {
        guard !existingIds.contains("the_full_set") else { return }
        let enrolments = (try? context.fetch(
            FetchDescriptor<ExerciseEnrolment>()
        )) ?? []
        let activeEnrolments = enrolments.filter { $0.isActive }
        guard !activeEnrolments.isEmpty else { return }
        guard let weekInterval = Calendar.current.dateInterval(of: .weekOfYear, for: sessionDate) else { return }
        let exerciseIds = Set(activeEnrolments.compactMap { $0.exerciseDefinition?.exerciseId })
        let sets = (try? context.fetch(FetchDescriptor<CompletedSet>())) ?? []
        let setsThisWeek = sets.filter { $0.sessionDate >= weekInterval.start && $0.sessionDate < weekInterval.end }
        let completedThisWeek = Set(setsThisWeek.map(\.exerciseId))
        if exerciseIds.isSubset(of: completedThisWeek) {
            results.append(Achievement(
                id: "the_full_set", category: "journey",
                unlockedAt: .now, sessionDate: sessionDate
            ))
        }
    }

    private func checkTimeOfDay(existingIds: Set<String>, sessionDate: Date,
                                 context: ModelContext, into results: inout [Achievement]) {
        let sets = (try? context.fetch(FetchDescriptor<CompletedSet>())) ?? []
        let cal = Calendar.current

        func distinctDates(where hourFilter: (Int) -> Bool) -> Int {
            let matching = sets.filter { hourFilter(cal.component(.hour, from: $0.completedAt)) }
            return Set(matching.map { cal.startOfDay(for: $0.completedAt) }).count
        }

        let timeAchievements: [(id: String, filter: (Int) -> Bool)] = [
            ("time_5am_club",     { $0 < 5 }),
            ("time_early_bird",   { $0 < 6 }),
            ("time_dawn_patrol",  { $0 < 7 }),
            ("time_lunch_legend", { $0 >= 12 && $0 < 13 }),
            ("time_night_owl",    { $0 >= 21 }),
        ]

        for (id, filter) in timeAchievements where !existingIds.contains(id) {
            if distinctDates(where: filter) >= 10 {
                results.append(Achievement(
                    id: id, category: "time",
                    unlockedAt: .now, sessionDate: sessionDate
                ))
            }
        }

        // Sunrise to Sunset — all six 4-hour blocks covered
        if !existingIds.contains("time_all_hours") {
            let blocks = [0..<4, 4..<8, 8..<12, 12..<16, 16..<20, 20..<24]
            let coveredBlocks = blocks.filter { range in
                sets.contains { range.contains(cal.component(.hour, from: $0.completedAt)) }
            }
            if coveredBlocks.count == 6 {
                results.append(Achievement(
                    id: "time_all_hours", category: "time",
                    unlockedAt: .now, sessionDate: sessionDate
                ))
            }
        }
    }

    private func checkHoliday(existingIds: Set<String>, sessionDate: Date,
                               into results: inout [Achievement]) {
        let matchingHolidays = HolidayCalendar.holidays(for: sessionDate)
        for holidayId in matchingHolidays where !existingIds.contains(holidayId) {
            results.append(Achievement(
                id: holidayId, category: "holiday",
                unlockedAt: .now, sessionDate: sessionDate
            ))
        }
    }

    private func checkTestGauntlet(existingIds: Set<String>, newExercise: String,
                                    context: ModelContext, sessionDate: Date,
                                    into results: inout [Achievement]) {
        guard !existingIds.contains("test_gauntlet") else { return }
        let existingAchievements = (try? context.fetch(FetchDescriptor<Achievement>())) ?? []
        let passedExercises = Set(
            existingAchievements
                .filter { $0.category == "milestone" && $0.id.hasPrefix("level_complete_") }
                .compactMap { $0.exerciseId }
        )
        let allPassed = passedExercises.union([newExercise])
        if allPassed.count >= 3 {
            results.append(Achievement(
                id: "test_gauntlet", category: "journey",
                unlockedAt: .now, sessionDate: sessionDate
            ))
        }
    }

    private func checkProgramComplete(existingIds: Set<String>, context: ModelContext,
                                       sessionDate: Date, into results: inout [Achievement]) {
        guard !existingIds.contains("program_complete") else { return }
        let enrolments = (try? context.fetch(
            FetchDescriptor<ExerciseEnrolment>()
        )) ?? []
        let activeEnrolments = enrolments.filter { $0.isActive }
        let allLevel3 = activeEnrolments.allSatisfy { $0.currentLevel > 3 || $0.currentDay > 18 }
        if !activeEnrolments.isEmpty && allLevel3 {
            results.append(Achievement(
                id: "program_complete", category: "milestone",
                unlockedAt: .now, sessionDate: sessionDate
            ))
        }
    }
}
