import Foundation

public struct WatchCompletionReport: Codable, Sendable {
    public let exerciseId: String
    public let level: Int
    public let dayNumber: Int
    public let completedSets: [WatchSetResult]
    public let completedAt: Date
}
