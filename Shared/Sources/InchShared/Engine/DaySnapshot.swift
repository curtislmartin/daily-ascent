import Foundation

/// Value-type snapshot of a day's prescription.
/// Used by SchedulingEngine for pure, Sendable computation.
public struct DaySnapshot: Sendable {
    public let dayNumber: Int
    public let sets: [Int]
    public let isTest: Bool

    public init(dayNumber: Int, sets: [Int], isTest: Bool) {
        self.dayNumber = dayNumber
        self.sets = sets
        self.isTest = isTest
    }
}

public extension DaySnapshot {
    init(_ day: DayPrescription) {
        self.init(dayNumber: day.dayNumber, sets: day.sets, isTest: day.isTest)
    }
}
