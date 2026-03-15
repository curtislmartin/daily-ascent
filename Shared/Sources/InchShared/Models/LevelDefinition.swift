import SwiftData

@Model
public final class LevelDefinition {
    public var level: Int = 1
    public var restDayPattern: [Int] = [2, 2, 3]
    public var testTarget: Int = 0
    public var extraRestBeforeTest: Int? = nil
    public var totalDays: Int = 0

    public var exercise: ExerciseDefinition?

    @Relationship(deleteRule: .cascade, inverse: \DayPrescription.level)
    public var days: [DayPrescription]? = []

    public init(level: Int = 1, restDayPattern: [Int] = [2, 2, 3], testTarget: Int = 0, extraRestBeforeTest: Int? = nil, totalDays: Int = 0) {
        self.level = level
        self.restDayPattern = restDayPattern
        self.testTarget = testTarget
        self.extraRestBeforeTest = extraRestBeforeTest
        self.totalDays = totalDays
    }
}
