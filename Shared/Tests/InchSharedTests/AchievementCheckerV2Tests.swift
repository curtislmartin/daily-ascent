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

    // MARK: - Seasonal

    @Test func januaryPersistenceWith20Workouts() throws {
        let context = try makeContext()
        for day in 1...20 {
            let date = makeDate(2026, 1, day, hour: 10)
            let set = CompletedSet(
                completedAt: date, sessionDate: date, exerciseId: "push_ups",
                level: 1, dayNumber: 1, setNumber: 1, targetReps: 10, actualReps: 10
            )
            context.insert(set)
        }
        try context.save()

        let checker = AchievementChecker()
        let results = checker.check(
            after: .workoutCompleted(exerciseId: "push_ups", totalReps: 10, level: 1, sessionDate: makeDate(2026, 1, 20)),
            in: context
        )
        #expect(results.contains { $0.id == "seasonal_january" })
    }

    @Test func januaryPersistenceNotWith19Workouts() throws {
        let context = try makeContext()
        for day in 1...19 {
            let date = makeDate(2026, 1, day, hour: 10)
            let set = CompletedSet(
                completedAt: date, sessionDate: date, exerciseId: "push_ups",
                level: 1, dayNumber: 1, setNumber: 1, targetReps: 10, actualReps: 10
            )
            context.insert(set)
        }
        try context.save()

        let checker = AchievementChecker()
        let results = checker.check(
            after: .workoutCompleted(exerciseId: "push_ups", totalReps: 10, level: 1, sessionDate: makeDate(2026, 1, 19)),
            in: context
        )
        #expect(results.allSatisfy { $0.id != "seasonal_january" })
    }

    @Test func yearRoundWithWorkoutsEveryMonth() throws {
        let context = try makeContext()
        for month in 1...12 {
            let date = makeDate(2026, month, 15, hour: 10)
            let set = CompletedSet(
                completedAt: date, sessionDate: date, exerciseId: "push_ups",
                level: 1, dayNumber: 1, setNumber: 1, targetReps: 10, actualReps: 10
            )
            context.insert(set)
        }
        try context.save()

        let checker = AchievementChecker()
        let results = checker.check(
            after: .workoutCompleted(exerciseId: "push_ups", totalReps: 10, level: 1, sessionDate: makeDate(2026, 12, 15)),
            in: context
        )
        #expect(results.contains { $0.id == "seasonal_year_round" })
    }

    @Test func yearRoundNotWithMissingMonth() throws {
        let context = try makeContext()
        for month in 1...11 {
            let date = makeDate(2026, month, 15, hour: 10)
            let set = CompletedSet(
                completedAt: date, sessionDate: date, exerciseId: "push_ups",
                level: 1, dayNumber: 1, setNumber: 1, targetReps: 10, actualReps: 10
            )
            context.insert(set)
        }
        try context.save()

        let checker = AchievementChecker()
        let results = checker.check(
            after: .workoutCompleted(exerciseId: "push_ups", totalReps: 10, level: 1, sessionDate: makeDate(2026, 11, 15)),
            in: context
        )
        #expect(results.allSatisfy { $0.id != "seasonal_year_round" })
    }

    // MARK: - Fun / Playful

    @Test func centuryClubWith100Workouts() throws {
        let context = try makeContext()
        // 100 distinct dates across 4 months
        let dates = (1...31).map { makeDate(2026, 1, $0) }
            + (1...28).map { makeDate(2026, 2, $0) }
            + (1...31).map { makeDate(2026, 3, $0) }
            + (1...10).map { makeDate(2026, 4, $0) }
        for date in dates {
            let set = CompletedSet(
                completedAt: date, sessionDate: date, exerciseId: "push_ups",
                level: 1, dayNumber: 1, setNumber: 1, targetReps: 10, actualReps: 10
            )
            context.insert(set)
        }
        try context.save()

        let checker = AchievementChecker()
        let results = checker.check(
            after: .workoutCompleted(exerciseId: "push_ups", totalReps: 10, level: 1, sessionDate: makeDate(2026, 4, 10)),
            in: context
        )
        #expect(results.contains { $0.id == "fun_century_club" })
    }

    @Test func thousandRepperWith1000Reps() throws {
        let context = try makeContext()
        for day in 1...20 {
            for setNum in 1...5 {
                let date = makeDate(2026, 3, day)
                let set = CompletedSet(
                    completedAt: date, sessionDate: date, exerciseId: "push_ups",
                    level: 1, dayNumber: 1, setNumber: setNum, targetReps: 10, actualReps: 10
                )
                context.insert(set)
            }
        }
        try context.save()

        let checker = AchievementChecker()
        let results = checker.check(
            after: .workoutCompleted(exerciseId: "push_ups", totalReps: 50, level: 1, sessionDate: makeDate(2026, 3, 20)),
            in: context
        )
        #expect(results.contains { $0.id == "fun_thousand_repper" })
    }

    @Test func tripleThreatWith3ExercisesInOneDay() throws {
        let context = try makeContext()
        let today = makeDate(2026, 3, 15)
        for ex in ["push_ups", "squats", "pull_ups"] {
            let set = CompletedSet(
                completedAt: today, sessionDate: today, exerciseId: ex,
                level: 1, dayNumber: 1, setNumber: 1, targetReps: 10, actualReps: 10
            )
            context.insert(set)
        }
        try context.save()

        let checker = AchievementChecker()
        let results = checker.check(
            after: .workoutCompleted(exerciseId: "pull_ups", totalReps: 10, level: 1, sessionDate: today),
            in: context
        )
        #expect(results.contains { $0.id == "fun_triple_threat" })
    }

    @Test func fiveADayWith5ExercisesInOneDay() throws {
        let context = try makeContext()
        let today = makeDate(2026, 3, 15)
        for ex in ["push_ups", "squats", "pull_ups", "dips", "rows"] {
            let set = CompletedSet(
                completedAt: today, sessionDate: today, exerciseId: ex,
                level: 1, dayNumber: 1, setNumber: 1, targetReps: 10, actualReps: 10
            )
            context.insert(set)
        }
        try context.save()

        let checker = AchievementChecker()
        let results = checker.check(
            after: .workoutCompleted(exerciseId: "rows", totalReps: 10, level: 1, sessionDate: today),
            in: context
        )
        #expect(results.contains { $0.id == "fun_five_a_day" })
    }

    @Test func groundhogDaySameExerciseSameRepsTwoDays() throws {
        let context = try makeContext()
        let yesterday = makeDate(2026, 3, 14)
        let today = makeDate(2026, 3, 15)
        for setNum in 1...3 {
            context.insert(CompletedSet(
                completedAt: yesterday, sessionDate: yesterday, exerciseId: "push_ups",
                level: 1, dayNumber: 1, setNumber: setNum, targetReps: 10, actualReps: 10
            ))
            context.insert(CompletedSet(
                completedAt: today, sessionDate: today, exerciseId: "push_ups",
                level: 1, dayNumber: 1, setNumber: setNum, targetReps: 10, actualReps: 10
            ))
        }
        try context.save()

        let checker = AchievementChecker()
        let results = checker.check(
            after: .workoutCompleted(exerciseId: "push_ups", totalReps: 30, level: 1, sessionDate: today),
            in: context
        )
        #expect(results.contains { $0.id == "fun_groundhog_day" })
    }

    @Test func metronomeMasterWith100MetronomeSets() throws {
        let context = try makeContext()
        for day in 1...20 {
            for setNum in 1...5 {
                let date = makeDate(2026, 3, day)
                let set = CompletedSet(
                    completedAt: date, sessionDate: date, exerciseId: "dead_bugs",
                    level: 1, dayNumber: 1, setNumber: setNum, targetReps: 10, actualReps: 10,
                    countingMode: .metronome
                )
                context.insert(set)
            }
        }
        try context.save()

        let checker = AchievementChecker()
        let results = checker.check(
            after: .workoutCompleted(exerciseId: "dead_bugs", totalReps: 50, level: 1, sessionDate: makeDate(2026, 3, 20)),
            in: context
        )
        #expect(results.contains { $0.id == "fun_metronome_master" })
    }

    @Test func plankMinutesWith10CumulativeMinutes() throws {
        let context = try makeContext()
        for day in 1...10 {
            let date = makeDate(2026, 3, day)
            let set = CompletedSet(
                completedAt: date, sessionDate: date, exerciseId: "plank",
                level: 1, dayNumber: 1, setNumber: 1, targetReps: 1, actualReps: 1,
                setDurationSeconds: 60.0
            )
            context.insert(set)
        }
        try context.save()

        let checker = AchievementChecker()
        let results = checker.check(
            after: .workoutCompleted(exerciseId: "plank", totalReps: 1, level: 1, sessionDate: makeDate(2026, 3, 10)),
            in: context
        )
        #expect(results.contains { $0.id == "fun_plank_minutes" })
    }

    @Test func testDayAceWith3ConsecutivePasses() throws {
        let context = try makeContext()
        for day in 1...3 {
            let date = makeDate(2026, 3, day)
            let set = CompletedSet(
                completedAt: date, sessionDate: date, exerciseId: "push_ups",
                level: 1, dayNumber: 10, setNumber: 1, targetReps: 20, actualReps: 25,
                isTest: true, testPassed: true
            )
            context.insert(set)
        }
        try context.save()

        let checker = AchievementChecker()
        let results = checker.check(
            after: .workoutCompleted(exerciseId: "push_ups", totalReps: 25, level: 1, sessionDate: makeDate(2026, 3, 3)),
            in: context
        )
        #expect(results.contains { $0.id == "fun_test_day_ace" })
    }

    @Test func tenThousandWith10000TotalReps() throws {
        let context = try makeContext()
        for day in 1...20 {
            for setNum in 1...5 {
                let date = makeDate(2026, 3, day)
                let set = CompletedSet(
                    completedAt: date, sessionDate: date, exerciseId: "push_ups",
                    level: 1, dayNumber: 1, setNumber: setNum, targetReps: 100, actualReps: 100
                )
                context.insert(set)
            }
        }
        try context.save()

        let checker = AchievementChecker()
        let results = checker.check(
            after: .workoutCompleted(exerciseId: "push_ups", totalReps: 500, level: 1, sessionDate: makeDate(2026, 3, 20)),
            in: context
        )
        #expect(results.contains { $0.id == "fun_ten_thousand" })
    }
}
