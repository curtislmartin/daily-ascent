import Foundation

struct WatchSetResult: Codable, Sendable {
    let setNumber: Int
    let targetReps: Int
    let actualReps: Int
    let durationSeconds: Double?
}
