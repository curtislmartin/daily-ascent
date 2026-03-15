import Foundation
import SwiftData
import InchShared

@Observable
final class EnrolmentViewModel {
    var selectedExerciseIds: Set<String> = []
    var startDate: Date = .now

    var canProceed: Bool { !selectedExerciseIds.isEmpty }

    func isSelected(_ exerciseId: String) -> Bool {
        selectedExerciseIds.contains(exerciseId)
    }

    func toggle(_ exerciseId: String) {
        if selectedExerciseIds.contains(exerciseId) {
            selectedExerciseIds.remove(exerciseId)
        } else {
            selectedExerciseIds.insert(exerciseId)
        }
    }

    /// Groups exercise definitions into display sections matching the UX spec.
    func sections(from definitions: [ExerciseDefinition]) -> [(label: String, definitions: [ExerciseDefinition])] {
        let sorted = definitions.sorted { $0.sortOrder < $1.sortOrder }
        let groups: [(label: String, groups: [MuscleGroup])] = [
            ("Upper Push", [.upperPush]),
            ("Upper Pull", [.upperPull]),
            ("Lower", [.lower, .lowerPosterior]),
            ("Core", [.coreFlexion, .coreStability]),
        ]
        return groups.compactMap { (label, muscleGroups) in
            let matched = sorted.filter { muscleGroups.contains($0.muscleGroup) }
            guard !matched.isEmpty else { return nil }
            return (label: label, definitions: matched)
        }
    }

    /// Creates ExerciseEnrolment records and saves. Does NOT create UserSettings.
    /// UserSettings is created after data consent to trigger the RootView transition.
    func saveEnrolments(from definitions: [ExerciseDefinition], context: ModelContext) throws {
        let selected = definitions.filter { selectedExerciseIds.contains($0.exerciseId) }
        for definition in selected {
            let enrolment = ExerciseEnrolment(enrolledAt: startDate)
            enrolment.exerciseDefinition = definition
            enrolment.nextScheduledDate = startDate
            context.insert(enrolment)
        }
        try context.save()
    }
}
