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
    func pushUpsHasFourLevels() throws {
        let container = try ModelContainerFactory.makeContainer(inMemory: true)
        let context = ModelContext(container)
        try ExerciseDataLoader().seedIfNeeded(context: context)
        let all = try context.fetch(FetchDescriptor<ExerciseDefinition>())
        let pushUps = try #require(all.first { $0.exerciseId == "push_ups" })
        #expect(pushUps.levels?.count == 4)
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

    @Test(.tags(.dataLoader))
    func pullUpsHasFourLevelsIncludingFoundation() throws {
        let container = try ModelContainerFactory.makeContainer(inMemory: true)
        let context = ModelContext(container)
        try ExerciseDataLoader().seedIfNeeded(context: context)
        let all = try context.fetch(FetchDescriptor<ExerciseDefinition>())
        let pullUps = try #require(all.first { $0.exerciseId == "pull_ups" })
        #expect(pullUps.levels?.count == 4)
        let foundation = try #require(pullUps.levels?.first { $0.level == 0 })
        #expect(foundation.variationName == "Negative Pull-Up")
        #expect(foundation.testTarget == 5)
        #expect(foundation.totalDays == 16)
    }

    @Test(.tags(.dataLoader))
    func dipsHasFourLevelsIncludingFoundation() throws {
        let container = try ModelContainerFactory.makeContainer(inMemory: true)
        let context = ModelContext(container)
        try ExerciseDataLoader().seedIfNeeded(context: context)
        let all = try context.fetch(FetchDescriptor<ExerciseDefinition>())
        let dips = try #require(all.first { $0.exerciseId == "dips" })
        #expect(dips.levels?.count == 4)
        let foundation = try #require(dips.levels?.first { $0.level == 0 })
        #expect(foundation.variationName == "Assisted Bench Dip")
        #expect(foundation.testTarget == 12)
        #expect(foundation.totalDays == 16)
    }

    @Test(.tags(.dataLoader))
    func foundationDay8IsCheckpointTest() throws {
        let container = try ModelContainerFactory.makeContainer(inMemory: true)
        let context = ModelContext(container)
        try ExerciseDataLoader().seedIfNeeded(context: context)
        let all = try context.fetch(FetchDescriptor<ExerciseDefinition>())
        let pullUps = try #require(all.first { $0.exerciseId == "pull_ups" })
        let foundation = try #require(pullUps.levels?.first { $0.level == 0 })
        let days = (foundation.days ?? []).sorted { $0.dayNumber < $1.dayNumber }
        let day8 = try #require(days.first { $0.dayNumber == 8 })
        #expect(day8.isTest == true)
        let day16 = try #require(days.first { $0.dayNumber == 16 })
        #expect(day16.isTest == true)
        let day7 = try #require(days.first { $0.dayNumber == 7 })
        #expect(day7.isTest == false)
    }

    @Test(.tags(.dataLoader))
    func pullUpsLevel1Has25Days() throws {
        let container = try ModelContainerFactory.makeContainer(inMemory: true)
        let context = ModelContext(container)
        try ExerciseDataLoader().seedIfNeeded(context: context)

        let all = try context.fetch(FetchDescriptor<ExerciseDefinition>())
        let pullUps = try #require(all.first { $0.exerciseId == "pull_ups" })
        let level1 = try #require(pullUps.levels?.first { $0.level == 1 })
        #expect(level1.totalDays == 25)
        #expect(level1.testTarget == 10)

        let days = (level1.days ?? []).sorted { $0.dayNumber < $1.dayNumber }
        #expect(days.count == 25)

        // Verify consolidation: days 12-13 should not exceed day 11 total volume
        let day11Total = days.first(where: { $0.dayNumber == 11 })?.sets.reduce(0, +) ?? 0
        let day12Total = days.first(where: { $0.dayNumber == 12 })?.sets.reduce(0, +) ?? 0
        let day13Total = days.first(where: { $0.dayNumber == 13 })?.sets.reduce(0, +) ?? 0
        #expect(day12Total <= day11Total, "Day 12 should be consolidation (volume <= day 11)")
        #expect(day13Total <= day11Total, "Day 13 should be consolidation (volume <= day 11)")
    }

    @Test(.tags(.dataLoader), arguments: [
        ("pull_ups", 3, 32, 30),
        ("push_ups", 3, 34, 100),
        ("squats", 3, 26, 150),
        ("dead_bugs", 3, 26, 80),
    ])
    func extendedL3Programs(exerciseId: String, level: Int, expectedDays: Int, expectedTarget: Int) throws {
        let container = try ModelContainerFactory.makeContainer(inMemory: true)
        let context = ModelContext(container)
        try ExerciseDataLoader().seedIfNeeded(context: context)

        let all = try context.fetch(FetchDescriptor<ExerciseDefinition>())
        let exercise = try #require(all.first { $0.exerciseId == exerciseId })
        let levelDef = try #require(exercise.levels?.first { $0.level == level })
        #expect(levelDef.totalDays == expectedDays)
        #expect(levelDef.testTarget == expectedTarget)

        let days = (levelDef.days ?? []).sorted { $0.dayNumber < $1.dayNumber }
        #expect(days.count == expectedDays)

        // Last day is test
        let lastDay = try #require(days.last)
        #expect(lastDay.isTest == true)
    }

    @Test(.tags(.dataLoader))
    func squatsStillHasThreeLevels() throws {
        let container = try ModelContainerFactory.makeContainer(inMemory: true)
        let context = ModelContext(container)
        try ExerciseDataLoader().seedIfNeeded(context: context)
        let all = try context.fetch(FetchDescriptor<ExerciseDefinition>())
        let squats = try #require(all.first { $0.exerciseId == "squats" })
        #expect(squats.levels?.count == 3)
        #expect(squats.levels?.contains { $0.level == 0 } == false)
    }
}
