import SwiftUI
import SwiftData
import InchShared

struct SessionDetailView: View {
    let sessionDate: Date

    @Query(sort: \CompletedSet.setNumber)
    private var allSets: [CompletedSet]

    private var sessionSets: [CompletedSet] {
        allSets.filter { Calendar.current.isDate($0.sessionDate, inSameDayAs: sessionDate) }
    }

    private var byExercise: [(name: String, sets: [CompletedSet])] {
        let grouped = Dictionary(grouping: sessionSets, by: \.exerciseId)
        return grouped.values.compactMap { sets in
            guard let first = sets.first else { return nil }
            let name = first.enrolment?.exerciseDefinition?.name ?? first.exerciseId
            return (name: name, sets: sets.sorted { $0.setNumber < $1.setNumber })
        }.sorted { $0.name < $1.name }
    }

    var body: some View {
        List {
            ForEach(byExercise, id: \.name) { group in
                Section(group.name) {
                    ForEach(group.sets, id: \.setNumber) { set in
                        SetRow(set: set)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(sessionDate.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SetRow: View {
    let set: CompletedSet

    var body: some View {
        HStack {
            Text("Set \(set.setNumber)")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)

            if set.isTest {
                Text("TEST")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.15), in: Capsule())
                    .foregroundStyle(.orange)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(set.actualReps) reps")
                    .font(.body)
                    .fontWeight(.medium)
                if set.actualReps != set.targetReps {
                    Text("target \(set.targetReps)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
