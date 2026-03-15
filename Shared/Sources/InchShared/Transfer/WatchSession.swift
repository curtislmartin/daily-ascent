import Foundation

struct WatchSession: Codable, Sendable {
    let exerciseId: String
    let exerciseName: String
    let color: String
    let level: Int
    let dayNumber: Int
    let sets: [Int]
    let isTest: Bool
    let testTarget: Int?
    let restSeconds: Int
    let countingMode: String
}
