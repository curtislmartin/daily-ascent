import Foundation

public struct WatchSetResult: Codable, Sendable {
    public let setNumber: Int
    public let targetReps: Int
    public let actualReps: Int
    public let durationSeconds: Double?

    public init(setNumber: Int, targetReps: Int, actualReps: Int, durationSeconds: Double?) {
        self.setNumber = setNumber
        self.targetReps = targetReps
        self.actualReps = actualReps
        self.durationSeconds = durationSeconds
    }
}
