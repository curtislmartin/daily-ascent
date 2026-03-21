import Foundation

/// A projected future training day, computed by SchedulingEngine.projectSchedule().
public struct ProjectedDay: Sendable, Identifiable {
    public let id: UUID
    public let dayNumber: Int
    public let scheduledDate: Date
    public let sets: [Int]
    public let isTest: Bool
    public let testTarget: Int

    public init(dayNumber: Int, scheduledDate: Date, sets: [Int], isTest: Bool, testTarget: Int) {
        self.id = UUID()
        self.dayNumber = dayNumber
        self.scheduledDate = scheduledDate
        self.sets = sets
        self.isTest = isTest
        self.testTarget = testTarget
    }
}
