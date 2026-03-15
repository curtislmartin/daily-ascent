import Foundation

public enum ScheduleConflict: Sendable {
    case doubleTest(date: Date, exerciseIds: [String])
    case testWithSameGroupTraining(date: Date, testExerciseId: String, trainingExerciseId: String)

    public var date: Date {
        switch self {
        case .doubleTest(let date, _): date
        case .testWithSameGroupTraining(let date, _, _): date
        }
    }
}
