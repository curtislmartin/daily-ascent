import Foundation

public struct WatchSession: Codable, Sendable {
    public let exerciseId: String
    public let exerciseName: String
    public let color: String
    public let level: Int
    public let dayNumber: Int
    public let sets: [Int]
    public let isTest: Bool
    public let testTarget: Int?
    public let restSeconds: Int
    public let countingMode: String
}
