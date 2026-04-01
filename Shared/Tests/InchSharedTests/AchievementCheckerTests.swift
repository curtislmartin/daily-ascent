import Testing
@testable import InchShared
import SwiftData

struct AchievementModelTests {

    @Test func defaultsToNotCelebrated() {
        let achievement = Achievement(
            id: "streak_7",
            category: "streak",
            unlockedAt: .now
        )
        #expect(achievement.wasCelebrated == false)
    }

    @Test func achievementNotificationEnabledDefaultsTrue() {
        let settings = UserSettings()
        #expect(settings.achievementNotificationEnabled == true)
    }
}

struct AchievementCheckerTests {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Schema(BodyweightSchemaV3.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test func firstWorkoutUnlockedOnFirstCompletion() throws {
        let context = try makeContext()
        let checker = AchievementChecker()
        let event = AchievementEvent.workoutCompleted(
            exerciseId: "push_ups", totalReps: 30, level: 1, sessionDate: .now
        )
        let results = checker.check(after: event, in: context)
        #expect(results.contains { $0.id == "first_workout" })
    }

    @Test func firstWorkoutNotDuplicatedOnSecondCompletion() throws {
        let context = try makeContext()
        let existing = Achievement(id: "first_workout", category: "milestone", unlockedAt: .now)
        context.insert(existing)
        try context.save()

        let checker = AchievementChecker()
        let event = AchievementEvent.workoutCompleted(
            exerciseId: "push_ups", totalReps: 30, level: 1, sessionDate: .now
        )
        let results = checker.check(after: event, in: context)
        #expect(results.allSatisfy { $0.id != "first_workout" })
    }

    @Test func personalBestReturnedWhenRepsExceedPrior() throws {
        let context = try makeContext()
        let prior = Achievement(
            id: "personal_best_push_ups",
            category: "performance",
            unlockedAt: .now.addingTimeInterval(-86400),
            exerciseId: "push_ups",
            numericValue: 25
        )
        context.insert(prior)
        try context.save()

        let checker = AchievementChecker()
        let event = AchievementEvent.workoutCompleted(
            exerciseId: "push_ups", totalReps: 35, level: 1, sessionDate: .now
        )
        let results = checker.check(after: event, in: context)
        #expect(results.contains { $0.id == "personal_best_push_ups" && $0.numericValue == 35 })
    }

    @Test func personalBestNotReturnedWhenRepsLower() throws {
        let context = try makeContext()
        let prior = Achievement(
            id: "personal_best_push_ups",
            category: "performance",
            unlockedAt: .now.addingTimeInterval(-86400),
            exerciseId: "push_ups",
            numericValue: 40
        )
        context.insert(prior)
        try context.save()

        let checker = AchievementChecker()
        let event = AchievementEvent.workoutCompleted(
            exerciseId: "push_ups", totalReps: 35, level: 1, sessionDate: .now
        )
        let results = checker.check(after: event, in: context)
        #expect(results.allSatisfy { $0.id != "personal_best_push_ups" })
    }

    @Test func streakAchievementUnlockedAtThreshold() throws {
        let context = try makeContext()
        let streak = StreakState()
        streak.currentStreak = 7
        context.insert(streak)
        try context.save()

        let checker = AchievementChecker()
        let event = AchievementEvent.streakUpdated
        let results = checker.check(after: event, in: context)
        #expect(results.contains { $0.id == "streak_7" })
    }
}
