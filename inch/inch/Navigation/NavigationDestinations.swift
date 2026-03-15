import SwiftUI
import SwiftData

enum WorkoutDestination: Hashable {
    case exercise(PersistentIdentifier)
    case testDay(PersistentIdentifier)
}

enum ProgramDestination: Hashable {
    case exerciseDetail(PersistentIdentifier)
}

extension View {
    func withWorkoutDestinations() -> some View {
        navigationDestination(for: WorkoutDestination.self) { destination in
            switch destination {
            case .exercise(let id):
                WorkoutSessionView(enrolmentId: id)
            case .testDay(let id):
                TestDayView(enrolmentId: id)
            }
        }
    }

    func withProgramDestinations() -> some View {
        navigationDestination(for: ProgramDestination.self) { destination in
            switch destination {
            case .exerciseDetail(let id):
                ExerciseDetailView(enrolmentId: id)
            }
        }
    }
}
