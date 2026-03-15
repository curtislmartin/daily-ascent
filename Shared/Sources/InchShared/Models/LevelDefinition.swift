import SwiftData

@Model
final class LevelDefinition {
    var level: Int = 1
    var restDayPattern: [Int] = [2, 2, 3]
    var testTarget: Int = 0
    var extraRestBeforeTest: Int? = nil
    var totalDays: Int = 0

    var exercise: ExerciseDefinition?

    @Relationship(deleteRule: .cascade, inverse: \DayPrescription.level)
    var days: [DayPrescription]? = []

    init(level: Int = 1, restDayPattern: [Int] = [2, 2, 3], testTarget: Int = 0, extraRestBeforeTest: Int? = nil, totalDays: Int = 0) {
        self.level = level
        self.restDayPattern = restDayPattern
        self.testTarget = testTarget
        self.extraRestBeforeTest = extraRestBeforeTest
        self.totalDays = totalDays
    }
}
