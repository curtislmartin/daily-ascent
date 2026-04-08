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
                sortOrder: index,
                metronomeBeatIntervalSeconds: dto.metronomeBeatIntervalSeconds ?? 0,
                metronomeBeatPattern: dto.metronomeBeatPattern ?? [],
                metronomeSidesPerRep: dto.metronomeSidesPerRep ?? 1
            )
            context.insert(exercise)

            for levelDTO in dto.levels {
                let levelDef = LevelDefinition(
                    level: levelDTO.level,
                    restDayPattern: levelDTO.restDayPattern,
                    testTarget: levelDTO.testTarget,
                    extraRestBeforeTest: levelDTO.extraRestBeforeTest,
                    totalDays: levelDTO.totalDays,
                    variationName: levelDTO.variationName
                )
                levelDef.exercise = exercise
                context.insert(levelDef)

                for dayDTO in levelDTO.days {
                    let day = DayPrescription(
                        dayNumber: dayDTO.day,
                        sets: dayDTO.sets,
                        isTest: dayDTO.isTest ?? (dayDTO.day == levelDTO.totalDays)
                    )
                    day.level = levelDef
                    context.insert(day)
                }
            }
        }

        try context.save()
    }

    /// Upserts exercise catalogue from the bundled JSON.
    /// Safe to call on every launch — inserts new exercises and updates changed fields.
    /// Never touches user enrolments or progress data.
    public func syncFromBundle(context: ModelContext) throws {
        guard let url = Bundle.module.url(forResource: "exercise-data", withExtension: "json") else {
            throw ExerciseDataError.jsonNotFound
        }
        let data = try Data(contentsOf: url)
        let root = try JSONDecoder().decode(ExerciseDataRoot.self, from: data)

        let existing = try context.fetch(FetchDescriptor<ExerciseDefinition>())
        let exerciseMap = Dictionary(uniqueKeysWithValues: existing.map { ($0.exerciseId, $0) })

        var dirty = false

        for (index, dto) in root.exercises.enumerated() {
            let exercise: ExerciseDefinition
            if let found = exerciseMap[dto.id] {
                exercise = found
                let mg = MuscleGroup(rawValue: dto.muscleGroup) ?? .upperPush
                let cm = CountingMode(rawValue: dto.countingMode) ?? .postSetConfirmation
                let beatInterval = dto.metronomeBeatIntervalSeconds ?? 0
                let beatPattern = dto.metronomeBeatPattern ?? []
                let sidesPerRep = dto.metronomeSidesPerRep ?? 1
                if exercise.name != dto.name                                         { exercise.name = dto.name; dirty = true }
                if exercise.color != dto.color                                       { exercise.color = dto.color; dirty = true }
                if exercise.muscleGroup != mg                                        { exercise.muscleGroup = mg; dirty = true }
                if exercise.countingMode != cm                                       { exercise.countingMode = cm; dirty = true }
                if exercise.defaultRestSeconds != dto.defaultRestSeconds             { exercise.defaultRestSeconds = dto.defaultRestSeconds; dirty = true }
                if exercise.sortOrder != index                                       { exercise.sortOrder = index; dirty = true }
                if exercise.metronomeBeatIntervalSeconds != beatInterval             { exercise.metronomeBeatIntervalSeconds = beatInterval; dirty = true }
                if exercise.metronomeBeatPattern != beatPattern                      { exercise.metronomeBeatPattern = beatPattern; dirty = true }
                if exercise.metronomeSidesPerRep != sidesPerRep                     { exercise.metronomeSidesPerRep = sidesPerRep; dirty = true }
            } else {
                exercise = ExerciseDefinition(
                    exerciseId: dto.id,
                    name: dto.name,
                    muscleGroup: MuscleGroup(rawValue: dto.muscleGroup) ?? .upperPush,
                    color: dto.color,
                    countingMode: CountingMode(rawValue: dto.countingMode) ?? .postSetConfirmation,
                    defaultRestSeconds: dto.defaultRestSeconds,
                    sortOrder: index,
                    metronomeBeatIntervalSeconds: dto.metronomeBeatIntervalSeconds ?? 0,
                    metronomeBeatPattern: dto.metronomeBeatPattern ?? [],
                    metronomeSidesPerRep: dto.metronomeSidesPerRep ?? 1
                )
                context.insert(exercise)
                dirty = true
            }

            let levelMap = (exercise.levels ?? []).reduce(into: [Int: LevelDefinition]()) { dict, level in
                if dict[level.level] == nil { dict[level.level] = level }
            }
            for levelDTO in dto.levels {
                let levelDef: LevelDefinition
                if let found = levelMap[levelDTO.level] {
                    levelDef = found
                    if levelDef.restDayPattern != levelDTO.restDayPattern           { levelDef.restDayPattern = levelDTO.restDayPattern; dirty = true }
                    if levelDef.testTarget != levelDTO.testTarget                   { levelDef.testTarget = levelDTO.testTarget; dirty = true }
                    if levelDef.extraRestBeforeTest != levelDTO.extraRestBeforeTest { levelDef.extraRestBeforeTest = levelDTO.extraRestBeforeTest; dirty = true }
                    if levelDef.totalDays != levelDTO.totalDays                     { levelDef.totalDays = levelDTO.totalDays; dirty = true }
                    if levelDef.variationName != levelDTO.variationName             { levelDef.variationName = levelDTO.variationName; dirty = true }
                } else {
                    levelDef = LevelDefinition(
                        level: levelDTO.level,
                        restDayPattern: levelDTO.restDayPattern,
                        testTarget: levelDTO.testTarget,
                        extraRestBeforeTest: levelDTO.extraRestBeforeTest,
                        totalDays: levelDTO.totalDays,
                        variationName: levelDTO.variationName
                    )
                    levelDef.exercise = exercise
                    context.insert(levelDef)
                    dirty = true
                }

                let dayMap = (levelDef.days ?? []).reduce(into: [Int: DayPrescription]()) { dict, day in
                    if dict[day.dayNumber] == nil { dict[day.dayNumber] = day }
                }
                for dayDTO in levelDTO.days {
                    let isTest = dayDTO.isTest ?? (dayDTO.day == levelDTO.totalDays)
                    if let found = dayMap[dayDTO.day] {
                        if found.sets != dayDTO.sets { found.sets = dayDTO.sets; dirty = true }
                        if found.isTest != isTest     { found.isTest = isTest; dirty = true }
                    } else {
                        let day = DayPrescription(dayNumber: dayDTO.day, sets: dayDTO.sets, isTest: isTest)
                        day.level = levelDef
                        context.insert(day)
                        dirty = true
                    }
                }
            }
        }

        // Remove exercises that are no longer in the JSON catalogue.
        let catalogueIds = Set(root.exercises.map { $0.id })
        for exercise in existing where !catalogueIds.contains(exercise.exerciseId) {
            context.delete(exercise)
            dirty = true
        }

        if dirty { try context.save() }
    }
}

public enum ExerciseDataError: Error {
    case jsonNotFound
}

// MARK: - Decoding types (internal for testability)

struct ExerciseDataRoot: Decodable {
    let exercises: [ExerciseDTO]
}

struct ExerciseDTO: Decodable {
    let id: String
    let name: String
    let muscleGroup: String
    let color: String
    let countingMode: String
    let defaultRestSeconds: Int
    let levels: [LevelDTO]
    let metronomeBeatIntervalSeconds: Double?
    let metronomeBeatPattern: [String]?
    let metronomeSidesPerRep: Int?
}

struct LevelDTO: Decodable {
    let level: Int
    let restDayPattern: [Int]
    let testTarget: Int
    let extraRestBeforeTest: Int?
    let totalDays: Int
    let variationName: String?
    let days: [DayDTO]
}

struct DayDTO: Decodable {
    let day: Int
    let sets: [Int]
    let isTest: Bool?
}
