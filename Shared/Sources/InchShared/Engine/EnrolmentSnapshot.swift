import Foundation

/// Value-type snapshot of an enrolment's scheduling state.
/// Used by SchedulingEngine for pure, Sendable computation.
public struct EnrolmentSnapshot: Sendable, Equatable {
    public var currentLevel: Int
    public var currentDay: Int
    public var lastCompletedDate: Date?
    public var restPatternIndex: Int
    public var enrolledAt: Date
    public var isActive: Bool

    public init(
        currentLevel: Int = 1,
        currentDay: Int = 1,
        lastCompletedDate: Date? = nil,
        restPatternIndex: Int = 0,
        enrolledAt: Date = Date.now,
        isActive: Bool = true
    ) {
        self.currentLevel = currentLevel
        self.currentDay = currentDay
        self.lastCompletedDate = lastCompletedDate
        self.restPatternIndex = restPatternIndex
        self.enrolledAt = enrolledAt
        self.isActive = isActive
    }
}

/// Value-type snapshot of a level's scheduling parameters.
public struct LevelSnapshot: Sendable, Equatable {
    public let level: Int
    public let restDayPattern: [Int]
    public let totalDays: Int
    public let extraRestBeforeTest: Int?
    public let testTarget: Int
    public let maxLevel: Int

    public init(
        level: Int,
        restDayPattern: [Int],
        totalDays: Int,
        extraRestBeforeTest: Int?,
        testTarget: Int,
        maxLevel: Int = 3
    ) {
        self.level = level
        self.restDayPattern = restDayPattern
        self.totalDays = totalDays
        self.extraRestBeforeTest = extraRestBeforeTest
        self.testTarget = testTarget
        self.maxLevel = maxLevel
    }
}

// MARK: - Convenience initialisers from @Model types

public extension EnrolmentSnapshot {
    init(_ enrolment: ExerciseEnrolment) {
        self.init(
            currentLevel: enrolment.currentLevel,
            currentDay: enrolment.currentDay,
            lastCompletedDate: enrolment.lastCompletedDate,
            restPatternIndex: enrolment.restPatternIndex,
            enrolledAt: enrolment.enrolledAt,
            isActive: enrolment.isActive
        )
    }
}

public extension LevelSnapshot {
    init(_ level: LevelDefinition) {
        self.init(
            level: level.level,
            restDayPattern: level.restDayPattern,
            totalDays: level.totalDays,
            extraRestBeforeTest: level.extraRestBeforeTest,
            testTarget: level.testTarget,
            maxLevel: level.exercise?.levels?.map(\.level).max() ?? 3
        )
    }
}
