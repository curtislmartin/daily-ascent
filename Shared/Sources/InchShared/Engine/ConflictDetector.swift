import Foundation

public struct ConflictDetector: Sendable {
    public init() {}

    public func detectConflicts(in sessions: [ProjectedSession]) -> [ScheduleConflict] {
        var conflicts: [ScheduleConflict] = []

        let grouped = Dictionary(grouping: sessions) {
            Calendar.current.startOfDay(for: $0.date)
        }

        for (date, daySessions) in grouped {
            let testSessions = daySessions.filter(\.isTest)
            let regularSessions = daySessions.filter { !$0.isTest }

            // Rule 1: No two tests on the same day
            if testSessions.count > 1 {
                conflicts.append(.doubleTest(
                    date: date,
                    exerciseIds: testSessions.map(\.exerciseId)
                ))
            }

            // Rule 2: Test + same-muscle-group training on the same day
            for test in testSessions {
                for regular in regularSessions {
                    if test.muscleGroup.conflictGroups.contains(regular.muscleGroup) {
                        conflicts.append(.testWithSameGroupTraining(
                            date: date,
                            testExerciseId: test.exerciseId,
                            trainingExerciseId: regular.exerciseId
                        ))
                    }
                }
            }
        }

        return conflicts
    }
}
