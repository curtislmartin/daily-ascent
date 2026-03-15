import Foundation
import SwiftData

public struct ExerciseDataLoader: Sendable {
    public init() {}

    /// Seeds the ModelContext with exercise data from the bundled JSON.
    /// Skips if exercises already exist (idempotent).
    public func seedIfNeeded(context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<ExerciseDefinition>())
        guard existing.isEmpty else { return }

        guard let url = Bundle.module.url(forResource: "exercise-data", withExtension: "json") else {
            throw ExerciseDataError.jsonNotFound
        }
        let data = try Data(contentsOf: url)
        let root = try JSONDecoder().decode(ExerciseDataRoot.self, from: data)

        for (index, dto) in root.exercises.enumerated() {
            let exercise = ExerciseDefinition(
                exerciseId: dto.id,
                name: dto.name,
                muscleGroup: MuscleGroup(rawValue: dto.muscleGroup) ?? .upperPush,
                color: dto.color,
                countingMode: CountingMode(rawValue: dto.countingMode) ?? .postSetConfirmation,
                defaultRestSeconds: dto.defaultRestSeconds,
                sortOrder: index
            )
            context.insert(exercise)

            for levelDTO in dto.levels {
                let levelDef = LevelDefinition(
                    level: levelDTO.level,
                    restDayPattern: levelDTO.restDayPattern,
                    testTarget: levelDTO.testTarget,
                    extraRestBeforeTest: levelDTO.extraRestBeforeTest,
                    totalDays: levelDTO.totalDays
                )
                levelDef.exercise = exercise
                context.insert(levelDef)

                for dayDTO in levelDTO.days {
                    let day = DayPrescription(
                        dayNumber: dayDTO.day,
                        sets: dayDTO.sets,
                        isTest: dayDTO.day == levelDTO.totalDays
                    )
                    day.level = levelDef
                    context.insert(day)
                }
            }
        }

        try context.save()
    }
}

public enum ExerciseDataError: Error {
    case jsonNotFound
}

// MARK: - Private decoding types

private struct ExerciseDataRoot: Decodable {
    let exercises: [ExerciseDTO]
}

private struct ExerciseDTO: Decodable {
    let id: String
    let name: String
    let muscleGroup: String
    let color: String
    let countingMode: String
    let defaultRestSeconds: Int
    let levels: [LevelDTO]
}

private struct LevelDTO: Decodable {
    let level: Int
    let restDayPattern: [Int]
    let testTarget: Int
    let extraRestBeforeTest: Int?
    let totalDays: Int
    let days: [DayDTO]
}

private struct DayDTO: Decodable {
    let day: Int
    let sets: [Int]
}
