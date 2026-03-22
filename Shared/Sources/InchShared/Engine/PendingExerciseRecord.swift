import Foundation

/// An exercise due today that has not yet been completed.
public struct PendingExerciseRecord: Sendable {
    public let exerciseId: String
    public let exerciseName: String
    public let muscleGroup: MuscleGroup
    public let isTest: Bool

    public init(
        exerciseId: String,
        exerciseName: String,
        muscleGroup: MuscleGroup,
        isTest: Bool
    ) {
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.muscleGroup = muscleGroup
        self.isTest = isTest
    }
}
