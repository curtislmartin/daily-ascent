import Foundation

struct WatchCompletionReport: Codable, Sendable {
    let exerciseId: String
    let level: Int
    let dayNumber: Int
    let completedSets: [WatchSetResult]
    let completedAt: Date
}
