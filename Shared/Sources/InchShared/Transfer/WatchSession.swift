import Foundation

public struct WatchSession: Codable, Sendable, Identifiable {
    public var id: String { exerciseId }
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

    public init(
        exerciseId: String,
        exerciseName: String,
        color: String,
        level: Int,
        dayNumber: Int,
        sets: [Int],
        isTest: Bool,
        testTarget: Int?,
        restSeconds: Int,
        countingMode: String
    ) {
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.color = color
        self.level = level
        self.dayNumber = dayNumber
        self.sets = sets
        self.isTest = isTest
        self.testTarget = testTarget
        self.restSeconds = restSeconds
        self.countingMode = countingMode
    }
}
