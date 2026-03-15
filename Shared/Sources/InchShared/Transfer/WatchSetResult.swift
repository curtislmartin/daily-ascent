import Foundation

public struct WatchSetResult: Codable, Sendable {
    public let setNumber: Int
    public let targetReps: Int
    public let actualReps: Int
    public let durationSeconds: Double?
}
