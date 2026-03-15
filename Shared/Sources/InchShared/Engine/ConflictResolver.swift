import Foundation

public struct ScheduleAdjustment: Sendable {
    public let enrolmentId: String
    public let reason: String

    public init(enrolmentId: String, reason: String) {
        self.enrolmentId = enrolmentId
        self.reason = reason
    }
}

public struct ConflictResolver: Sendable {
    public let maxIterations = 5

    public init() {}

    /// Resolve a set of conflicts and return the adjustments needed.
    /// Each adjustment indicates which enrolment's nextScheduledDate should be pushed by 1 day.
    public func resolve(
        conflicts: [ScheduleConflict],
        sessions: [ProjectedSession],
        remainingDays: (String) -> Int
    ) -> [ScheduleAdjustment] {
        var adjustments: [ScheduleAdjustment] = []
        let sorted = conflicts.sorted { $0.date < $1.date }

        for conflict in sorted {
            switch conflict {
            case .doubleTest(_, let exerciseIds):
                let involved = sessions.filter { exerciseIds.contains($0.exerciseId) && $0.isTest }
                // Keep the exercise closer to programme end (fewer remaining days)
                let byPriority = involved.sorted { remainingDays($0.enrolmentId) < remainingDays($1.enrolmentId) }
                if let toPush = byPriority.last {
                    adjustments.append(ScheduleAdjustment(
                        enrolmentId: toPush.enrolmentId,
                        reason: "Avoiding test day collision"
                    ))
                }

            case .testWithSameGroupTraining(_, _, let trainingExerciseId):
                let session = sessions.first { $0.exerciseId == trainingExerciseId && !$0.isTest }
                if let s = session {
                    adjustments.append(ScheduleAdjustment(
                        enrolmentId: s.enrolmentId,
                        reason: "Resting muscle group for test day"
                    ))
                }
            }
        }

        return adjustments
    }
}
