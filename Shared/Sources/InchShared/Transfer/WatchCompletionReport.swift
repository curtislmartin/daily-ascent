import Foundation

public struct WatchCompletionReport: Codable, Sendable {
    public let exerciseId: String
    public let level: Int
    public let dayNumber: Int
    public let completedSets: [WatchSetResult]
    public let completedAt: Date

    public init(exerciseId: String, level: Int, dayNumber: Int, completedSets: [WatchSetResult], completedAt: Date) {
        self.exerciseId = exerciseId
        self.level = level
        self.dayNumber = dayNumber
        self.completedSets = completedSets
        self.completedAt = completedAt
    }
}
