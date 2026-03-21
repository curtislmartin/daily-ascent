import Foundation

/// Snapshot of today's training state passed to DailyLoadAdvisor.
/// Assembled by TodayViewModel from SwiftData — never constructed inside the advisor.
public struct DailyLoadContext: Sendable {
    /// Exercises fully completed so far today, one record per exercise.
    /// Empty until the user finishes their first exercise.
    public let completedToday: [CompletedExerciseRecord]

    /// Exercises due today that have not yet been completed.
    public let dueButNotDone: [PendingExerciseRecord]

    /// Exercises with a test day projected strictly within the next 48 hours
    /// (today's test days excluded — they are handled via completedToday or dueButNotDone).
    public let testDaysInNext48h: [(exerciseId: String, exerciseName: String, scheduledDate: Date)]

    /// Exercises completed yesterday. Used for the lookback penalty.
    public let yesterdayCompletions: [CompletedExerciseRecord]

    public init(
        completedToday: [CompletedExerciseRecord],
        dueButNotDone: [PendingExerciseRecord],
        testDaysInNext48h: [(exerciseId: String, exerciseName: String, scheduledDate: Date)],
        yesterdayCompletions: [CompletedExerciseRecord]
    ) {
        self.completedToday = completedToday
        self.dueButNotDone = dueButNotDone
        self.testDaysInNext48h = testDaysInNext48h
        self.yesterdayCompletions = yesterdayCompletions
    }
}

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
