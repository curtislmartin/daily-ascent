import SwiftData

@Model
final class DayPrescription {
    var dayNumber: Int = 0
    var sets: [Int] = []
    var isTest: Bool = false

    var level: LevelDefinition?

    // Computed (not stored)
    var totalReps: Int { sets.reduce(0, +) }
    var setCount: Int { sets.count }

    init(dayNumber: Int = 0, sets: [Int] = [], isTest: Bool = false) {
        self.dayNumber = dayNumber
        self.sets = sets
        self.isTest = isTest
    }
}
