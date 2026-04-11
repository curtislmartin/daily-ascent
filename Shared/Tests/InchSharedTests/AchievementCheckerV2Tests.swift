import Testing
@testable import InchShared
import SwiftData
import Foundation

struct AchievementCheckerV2Tests {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Schema(BodyweightSchemaV3.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func makeDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return Calendar.current.date(from: components)!
    }

    @Test func earlyBirdUnlockedWith10EarlySessions() throws {
        let context = try makeContext()
        for day in 1...10 {
            let date = makeDate(2026, 1, day, hour: 5)
            let set = CompletedSet(completedAt: date, sessionDate: date, exerciseId: "push_ups")
            context.insert(set)
        }
        try context.save()

        let checker = AchievementChecker()
        let sessionDate = makeDate(2026, 1, 10, hour: 5)
        let event = AchievementEvent.workoutCompleted(
            exerciseId: "push_ups", totalReps: 10, level: 1, sessionDate: sessionDate
        )
        let results = checker.check(after: event, in: context)
        #expect(results.contains { $0.id == "time_early_bird" })
    }

    @Test func earlyBirdNotUnlockedWith9EarlySessions() throws {
        let context = try makeContext()
        for day in 1...9 {
            let date = makeDate(2026, 1, day, hour: 5)
            let set = CompletedSet(completedAt: date, sessionDate: date, exerciseId: "push_ups")
            context.insert(set)
        }
        try context.save()

        let checker = AchievementChecker()
        let sessionDate = makeDate(2026, 1, 9, hour: 5)
        let event = AchievementEvent.workoutCompleted(
            exerciseId: "push_ups", totalReps: 10, level: 1, sessionDate: sessionDate
        )
        let results = checker.check(after: event, in: context)
        #expect(results.allSatisfy { $0.id != "time_early_bird" })
    }

    @Test func nightOwlUnlockedWith10LateSessions() throws {
        let context = try makeContext()
        for day in 1...10 {
            let date = makeDate(2026, 1, day, hour: 21)
            let set = CompletedSet(completedAt: date, sessionDate: date, exerciseId: "push_ups")
            context.insert(set)
        }
        try context.save()

        let checker = AchievementChecker()
        let sessionDate = makeDate(2026, 1, 10, hour: 21)
        let event = AchievementEvent.workoutCompleted(
            exerciseId: "push_ups", totalReps: 10, level: 1, sessionDate: sessionDate
        )
        let results = checker.check(after: event, in: context)
        #expect(results.contains { $0.id == "time_night_owl" })
    }

    @Test func allHoursUnlockedWhenAllBlocksCovered() throws {
        let context = try makeContext()
        // Cover each of the six 4-hour blocks: 0-3, 4-7, 8-11, 12-15, 16-19, 20-23
        let blockHours = [2, 6, 10, 14, 18, 22]
        for (index, hour) in blockHours.enumerated() {
            let date = makeDate(2026, 1, index + 1, hour: hour)
            let set = CompletedSet(completedAt: date, sessionDate: date, exerciseId: "push_ups")
            context.insert(set)
        }
        try context.save()

        let checker = AchievementChecker()
        let sessionDate = makeDate(2026, 1, 6, hour: 22)
        let event = AchievementEvent.workoutCompleted(
            exerciseId: "push_ups", totalReps: 10, level: 1, sessionDate: sessionDate
        )
        let results = checker.check(after: event, in: context)
        #expect(results.contains { $0.id == "time_all_hours" })
    }

    // MARK: - Holiday

    @Test func christmasGainsUnlockedOnChristmas() throws {
        let context = try makeContext()
        let christmasDate = makeDate(2026, 12, 25, hour: 10)
        let set = CompletedSet(
            completedAt: christmasDate, sessionDate: christmasDate, exerciseId: "push_ups",
            level: 1, dayNumber: 1, setNumber: 1, targetReps: 10, actualReps: 10
        )
        context.insert(set)
        try context.save()

        let checker = AchievementChecker()
        let results = checker.check(
            after: .workoutCompleted(exerciseId: "push_ups", totalReps: 10, level: 1, sessionDate: christmasDate),
            in: context
        )
        #expect(results.contains { $0.id == "holiday_christmas" })
    }

    @Test func noHolidayOnRegularDay() throws {
        let context = try makeContext()
        let date = makeDate(2026, 6, 15, hour: 10)
        let set = CompletedSet(
            completedAt: date, sessionDate: date, exerciseId: "push_ups",
            level: 1, dayNumber: 1, setNumber: 1, targetReps: 10, actualReps: 10
        )
        context.insert(set)
        try context.save()

        let checker = AchievementChecker()
        let results = checker.check(
            after: .workoutCompleted(exerciseId: "push_ups", totalReps: 10, level: 1, sessionDate: date),
            in: context
        )
        #expect(results.allSatisfy { !$0.id.hasPrefix("holiday_") })
    }

    @Test func easterAchievementOnEasterSunday() throws {
        let context = try makeContext()
        // Easter 2026 is April 5
        let date = makeDate(2026, 4, 5, hour: 10)
        let set = CompletedSet(
            completedAt: date, sessionDate: date, exerciseId: "push_ups",
            level: 1, dayNumber: 1, setNumber: 1, targetReps: 10, actualReps: 10
        )
        context.insert(set)
        try context.save()

        let checker = AchievementChecker()
        let results = checker.check(
            after: .workoutCompleted(exerciseId: "push_ups", totalReps: 10, level: 1, sessionDate: date),
            in: context
        )
        #expect(results.contains { $0.id == "holiday_easter" })
    }

    @Test func holidayNotDuplicated() throws {
        let context = try makeContext()
        let existing = Achievement(id: "holiday_christmas", category: "holiday", unlockedAt: .now)
        context.insert(existing)
        try context.save()

        let date = makeDate(2027, 12, 25, hour: 10)
        let set = CompletedSet(
            completedAt: date, sessionDate: date, exerciseId: "push_ups",
            level: 1, dayNumber: 1, setNumber: 1, targetReps: 10, actualReps: 10
        )
        context.insert(set)
        try context.save()

        let checker = AchievementChecker()
        let results = checker.check(
            after: .workoutCompleted(exerciseId: "push_ups", totalReps: 10, level: 1, sessionDate: date),
            in: context
        )
        #expect(results.allSatisfy { $0.id != "holiday_christmas" })
    }
}
