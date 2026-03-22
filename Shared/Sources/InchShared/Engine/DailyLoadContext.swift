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
