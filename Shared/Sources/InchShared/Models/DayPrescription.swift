import SwiftData

@Model
public final class DayPrescription {
    public var dayNumber: Int = 0
    public var sets: [Int] = []
    public var isTest: Bool = false

    public var level: LevelDefinition?

    // Computed (not stored)
    public var totalReps: Int { sets.reduce(0, +) }
    public var setCount: Int { sets.count }

    public init(dayNumber: Int = 0, sets: [Int] = [], isTest: Bool = false) {
        self.dayNumber = dayNumber
        self.sets = sets
        self.isTest = isTest
    }
}
