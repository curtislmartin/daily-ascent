import Foundation
import InchShared

struct SessionGroup: Identifiable {
    let id: Date  // start of day
    let exercises: [ExerciseSummary]
    var totalReps: Int { exercises.reduce(0) { $0 + $1.totalReps } }
}

struct ExerciseSummary: Identifiable {
    let id: String  // exerciseId
    let name: String
    let color: String
    let setCount: Int
    let totalReps: Int
}

@Observable
final class HistoryViewModel {

    func grouped(sets: [CompletedSet]) -> [SessionGroup] {
        let byDay = Dictionary(grouping: sets) {
            Calendar.current.startOfDay(for: $0.sessionDate)
        }
        return byDay.keys.sorted(by: >).map { day in
            let daySets = byDay[day] ?? []
            let byExercise = Dictionary(grouping: daySets, by: \.exerciseId)
            let summaries = byExercise.values.compactMap { exerciseSets -> ExerciseSummary? in
                guard let first = exerciseSets.first else { return nil }
                let name = exerciseSets.first?.enrolment?.exerciseDefinition?.name ?? first.exerciseId
                let color = exerciseSets.first?.enrolment?.exerciseDefinition?.color ?? ""
                return ExerciseSummary(
                    id: first.exerciseId,
                    name: name,
                    color: color,
                    setCount: exerciseSets.count,
                    totalReps: exerciseSets.reduce(0) { $0 + $1.actualReps }
                )
            }.sorted { $0.name < $1.name }
            return SessionGroup(id: day, exercises: summaries)
        }
    }
}
