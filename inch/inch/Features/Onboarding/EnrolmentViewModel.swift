import Foundation
import SwiftData
import InchShared

@Observable
final class EnrolmentViewModel {
    var selectedExerciseIds: Set<String> = []
    var startDate: Date = .now
    var levelChoices: [String: Int] = [:]

    var canProceed: Bool { !selectedExerciseIds.isEmpty }

    /// Returns recommended level (1, 2, or 3) given a max-rep score.
    /// testTargets must contain at least 2 entries: [L1target, L2target, ...].
    static func recommendLevel(score: Int, testTargets: [Int]) -> Int {
        guard testTargets.count >= 2 else { return 1 }
        if score < testTargets[0] { return 1 }
        if score < testTargets[1] { return 2 }
        return 3
    }

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

    func selectAll(ids: [String]) {
        selectedExerciseIds = Set(ids)
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
        let existing = (try? context.fetch(FetchDescriptor<ExerciseEnrolment>(
            predicate: #Predicate { $0.isActive }
        ))) ?? []
        let existingIds = Set(existing.compactMap { $0.exerciseDefinition?.exerciseId })

        let selected = definitions.filter {
            selectedExerciseIds.contains($0.exerciseId) && !existingIds.contains($0.exerciseId)
        }
        for definition in selected {
            let chosenLevel = levelChoices[definition.exerciseId] ?? 1
            let enrolment = ExerciseEnrolment(enrolledAt: startDate, currentLevel: chosenLevel)
            enrolment.exerciseDefinition = definition
            enrolment.nextScheduledDate = startDate
            context.insert(enrolment)
        }
        try context.save()
    }
}
