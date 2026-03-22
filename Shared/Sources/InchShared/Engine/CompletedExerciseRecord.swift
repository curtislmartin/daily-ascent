import Foundation

/// One completed exercise session (all sets for one exercise on a given day).
public struct CompletedExerciseRecord: Sendable {
    /// Matches ExerciseDefinition.exerciseId (e.g. "push_ups")
    public let exerciseId: String
    /// Display name for the exercise (e.g. "Push-Ups")
    public let exerciseName: String
    public let muscleGroup: MuscleGroup
    /// True if this session was a test day (all sets share the same isTest value)
    public let isTest: Bool
    /// True if the exercise's nextScheduledDate was before today when TodayViewModel loaded
    public let wasRescheduled: Bool

    public init(
        exerciseId: String,
        exerciseName: String,
        muscleGroup: MuscleGroup,
        isTest: Bool,
        wasRescheduled: Bool
    ) {
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.muscleGroup = muscleGroup
        self.isTest = isTest
        self.wasRescheduled = wasRescheduled
    }
}
