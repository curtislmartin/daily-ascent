import Testing
import Foundation
import SwiftData
@testable import InchShared

struct ExerciseDataLoaderTests {
    @Test(.tags(.dataLoader))
    func loadsAllSixExercises() throws {
        let container = try ModelContainerFactory.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let loader = ExerciseDataLoader()
        try loader.seedIfNeeded(context: context)

        let exercises = try context.fetch(FetchDescriptor<ExerciseDefinition>())
        #expect(exercises.count == 6)
    }

    @Test(.tags(.dataLoader))
    func pushUpsHasThreeLevels() throws {
        let container = try ModelContainerFactory.makeContainer(inMemory: true)
        let context = ModelContext(container)
        try ExerciseDataLoader().seedIfNeeded(context: context)

        let all = try context.fetch(FetchDescriptor<ExerciseDefinition>())
        let pushUps = try #require(all.first { $0.exerciseId == "push_ups" })
        #expect(pushUps.levels?.count == 3)
    }

    @Test(.tags(.dataLoader))
    func totalDayPrescriptionsAreCorrect() throws {
        let container = try ModelContainerFactory.makeContainer(inMemory: true)
        let context = ModelContext(container)
        try ExerciseDataLoader().seedIfNeeded(context: context)

        let days = try context.fetch(FetchDescriptor<DayPrescription>())
        // 6 exercises × 3 levels × 10-25 days each
        #expect(days.count > 250)
    }

    @Test(.tags(.dataLoader))
    func seedingTwiceDoesNotDuplicate() throws {
        let container = try ModelContainerFactory.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let loader = ExerciseDataLoader()
        try loader.seedIfNeeded(context: context)
        try loader.seedIfNeeded(context: context)

        let exercises = try context.fetch(FetchDescriptor<ExerciseDefinition>())
        #expect(exercises.count == 6)
    }

    @Test(.tags(.dataLoader))
    func lastDayOfEachLevelIsMarkedAsTest() throws {
        let container = try ModelContainerFactory.makeContainer(inMemory: true)
        let context = ModelContext(container)
        try ExerciseDataLoader().seedIfNeeded(context: context)

        let levels = try context.fetch(FetchDescriptor<LevelDefinition>())
        for level in levels {
            let sortedDays = (level.days ?? []).sorted { $0.dayNumber < $1.dayNumber }
            let lastDay = try #require(sortedDays.last)
            #expect(lastDay.isTest == true, "Last day \(lastDay.dayNumber) of level \(level.level) should be marked isTest")
            let nonLastDays = sortedDays.dropLast()
            for day in nonLastDays {
                #expect(day.isTest == false, "Day \(day.dayNumber) should not be marked isTest")
            }
        }
    }

    @Test(.tags(.dataLoader))
    func exerciseSortOrderIsPreserved() throws {
        let container = try ModelContainerFactory.makeContainer(inMemory: true)
        let context = ModelContext(container)
        try ExerciseDataLoader().seedIfNeeded(context: context)

        let exercises = try context.fetch(FetchDescriptor<ExerciseDefinition>())
            .sorted { $0.sortOrder < $1.sortOrder }
        let sortOrders = exercises.map(\.sortOrder)
        #expect(sortOrders == Array(0..<6))
    }
}
