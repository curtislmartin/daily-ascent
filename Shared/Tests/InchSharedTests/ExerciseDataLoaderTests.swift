import Testing
import Foundation
import SwiftData
@testable import InchShared

struct ExerciseDataLoaderTests {
    @Test(.tags(.dataLoader))
    func loadsAllNineExercises() throws {
        let container = try ModelContainerFactory.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let loader = ExerciseDataLoader()
        try loader.seedIfNeeded(context: context)

        let exercises = try context.fetch(FetchDescriptor<ExerciseDefinition>())
        #expect(exercises.count == 9)
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
        #expect(exercises.count == 9)
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
        #expect(sortOrders == Array(0..<9))
    }

    @Test(.tags(.dataLoader))
    func variationNameParsedForLevels() throws {
        let json = """
        {
          "exercises": [{
            "id": "hip_hinge",
            "name": "Hip Hinge",
            "muscleGroup": "lower_posterior",
            "color": "#A0522D",
            "countingMode": "post_set_confirmation",
            "defaultRestSeconds": 90,
            "levels": [{
              "level": 1,
              "variationName": "Glute Bridge",
              "restDayPattern": [2, 2, 3],
              "testTarget": 30,
              "totalDays": 10,
              "days": [{"day": 1, "sets": [10, 10, 10]}]
            }]
          }]
        }
        """
        let data = try #require(json.data(using: .utf8))
        let root = try JSONDecoder().decode(ExerciseDataRoot.self, from: data)
        let level = try #require(root.exercises.first?.levels.first)
        #expect(level.variationName == "Glute Bridge")
    }

    @Test(.tags(.dataLoader))
    func variationNameNilWhenAbsent() throws {
        let json = """
        {
          "exercises": [{
            "id": "push_ups",
            "name": "Push-Ups",
            "muscleGroup": "upper_push",
            "color": "#E8722A",
            "countingMode": "post_set_confirmation",
            "defaultRestSeconds": 60,
            "levels": [{
              "level": 1,
              "restDayPattern": [2, 2, 3],
              "testTarget": 20,
              "totalDays": 1,
              "days": [{"day": 1, "sets": [5, 5, 5]}]
            }]
          }]
        }
        """
        let data = try #require(json.data(using: .utf8))
        let root = try JSONDecoder().decode(ExerciseDataRoot.self, from: data)
        let level = try #require(root.exercises.first?.levels.first)
        #expect(level.variationName == nil)
    }

    @Test(.tags(.dataLoader))
    func timedExerciseSetsStoredAsSeconds() throws {
        let json = """
        {
          "exercises": [{
            "id": "plank",
            "name": "Plank",
            "muscleGroup": "core_stability",
            "color": "#5B8A72",
            "countingMode": "timed",
            "defaultRestSeconds": 90,
            "levels": [{
              "level": 1,
              "restDayPattern": [2, 2, 3],
              "testTarget": 60,
              "totalDays": 1,
              "days": [{"day": 1, "sets": [20, 20, 20]}]
            }]
          }]
        }
        """
        let data = try #require(json.data(using: .utf8))
        let root = try JSONDecoder().decode(ExerciseDataRoot.self, from: data)
        let day = try #require(root.exercises.first?.levels.first?.days.first)
        #expect(day.sets == [20, 20, 20])
    }

    @Test(.tags(.dataLoader))
    func syncFromBundleOnEmptyDBLoadsAllExercises() throws {
        let container = try ModelContainerFactory.makeContainer(inMemory: true)
        let context = ModelContext(container)
        try ExerciseDataLoader().syncFromBundle(context: context)

        let exercises = try context.fetch(FetchDescriptor<ExerciseDefinition>())
        #expect(exercises.count == 9)
    }

    @Test(.tags(.dataLoader))
    func syncFromBundleInsertsNewExercisesIntoExistingDB() throws {
        let container = try ModelContainerFactory.makeContainer(inMemory: true)
        let context = ModelContext(container)

        // Simulate existing user who only had push_ups
        let pushUps = ExerciseDefinition(exerciseId: "push_ups", name: "Push-Ups", sortOrder: 0)
        context.insert(pushUps)
        try context.save()

        try ExerciseDataLoader().syncFromBundle(context: context)

        let exercises = try context.fetch(FetchDescriptor<ExerciseDefinition>())
        #expect(exercises.count == 9)
        #expect(exercises.contains { $0.exerciseId == "hip_hinge" })
        #expect(exercises.contains { $0.exerciseId == "rows" })
        #expect(exercises.contains { $0.exerciseId == "dips" })
    }

    @Test(.tags(.dataLoader))
    func syncFromBundleUpdatesChangedExerciseName() throws {
        let container = try ModelContainerFactory.makeContainer(inMemory: true)
        let context = ModelContext(container)

        let pushUps = ExerciseDefinition(exerciseId: "push_ups", name: "Old Name", sortOrder: 0)
        context.insert(pushUps)
        try context.save()

        try ExerciseDataLoader().syncFromBundle(context: context)

        let all = try context.fetch(FetchDescriptor<ExerciseDefinition>())
        let updated = try #require(all.first { $0.exerciseId == "push_ups" })
        #expect(updated.name == "Push-Ups")
    }

    @Test(.tags(.dataLoader))
    func syncFromBundleIsIdempotent() throws {
        let container = try ModelContainerFactory.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let loader = ExerciseDataLoader()
        try loader.syncFromBundle(context: context)
        try loader.syncFromBundle(context: context)

        let exercises = try context.fetch(FetchDescriptor<ExerciseDefinition>())
        #expect(exercises.count == 9)
    }

    @Test(.tags(.dataLoader))
    func syncFromBundleSetsIsTestFromJSON() throws {
        let container = try ModelContainerFactory.makeContainer(inMemory: true)
        let context = ModelContext(container)
        try ExerciseDataLoader().syncFromBundle(context: context)

        let all = try context.fetch(FetchDescriptor<ExerciseDefinition>())
        let pushUps = try #require(all.first { $0.exerciseId == "push_ups" })
        let level1 = try #require(pushUps.levels?.first { $0.level == 1 })
        let day10 = try #require(level1.days?.first { $0.dayNumber == 10 })
        #expect(day10.isTest == true)
        let day1 = try #require(level1.days?.first { $0.dayNumber == 1 })
        #expect(day1.isTest == false)
    }
}
