import Foundation

/// A projected training session used for conflict detection.
public struct ProjectedSession: Sendable {
    public let exerciseId: String
    public let muscleGroup: MuscleGroup
    public let isTest: Bool
    public let date: Date
    public let enrolmentId: String

    public init(
        exerciseId: String,
        muscleGroup: MuscleGroup,
        isTest: Bool,
        date: Date,
        enrolmentId: String
    ) {
        self.exerciseId = exerciseId
        self.muscleGroup = muscleGroup
        self.isTest = isTest
        self.date = date
        self.enrolmentId = enrolmentId
    }
}
