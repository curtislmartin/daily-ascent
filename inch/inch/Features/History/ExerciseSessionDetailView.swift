import SwiftUI
import SwiftData
import InchShared

struct ExerciseSessionDetailView: View {
    let exerciseId: String
    let sessionDate: Date

    @Query private var sets: [CompletedSet]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var showDeleteError = false

    @State private var viewModel = HistoryViewModel()

    init(exerciseId: String, sessionDate: Date) {
        self.exerciseId = exerciseId
        self.sessionDate = sessionDate
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: sessionDate)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        _sets = Query(
            filter: #Predicate { set in
                set.exerciseId == exerciseId &&
                set.sessionDate >= start &&
                set.sessionDate < end
            },
            sort: \.setNumber
        )
    }

    private var exerciseName: String {
        sets.first?.enrolment?.exerciseDefinition?.name ?? exerciseId
    }

    private var prescribedSetCount: Int {
        guard let first = sets.first else { return 0 }
        return first.enrolment?.exerciseDefinition?.levels?
            .first { $0.level == first.level }?
            .days?.first { $0.dayNumber == first.dayNumber }?
            .sets.count ?? 0
    }

    private var isTimed: Bool {
        sets.first?.countingMode == .timed
    }

    private var totalReps: Int {
        sets.reduce(0) { $0 + $1.actualReps }
    }

    private var totalDurationSeconds: Double {
        sets.compactMap(\.setDurationSeconds).reduce(0, +)
    }

    var body: some View {
        List {
            setsSection
            summarySection
            deleteSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(exerciseName)
                        .font(.headline)
                    Text(sessionDate.formatted(.dateTime.day().month(.abbreviated).year()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .confirmationDialog(
            "Delete this session?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Session", role: .destructive) {
                do {
                    try viewModel.deleteSession(
                        exerciseId: exerciseId,
                        date: sessionDate,
                        context: context
                    )
                    dismiss()
                } catch {
                    showDeleteError = true
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone. Progress will be rolled back if the session was fully completed.")
        }
        .alert("Delete Failed", isPresented: $showDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The session could not be deleted. Please try again.")
        }
    }

    @ViewBuilder
    private var setsSection: some View {
        Section("Sets") {
            ForEach(sets) { set in
                SetRow(set: set, isTimed: isTimed)
            }
            // Greyed-out uncompleted sets (partial sessions only)
            if sets.count < prescribedSetCount {
                ForEach((sets.count + 1)...prescribedSetCount, id: \.self) { number in
                    HStack {
                        Text("Set \(number)")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("—")
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var summarySection: some View {
        Section("Summary") {
            if isTimed {
                LabeledContent("Completed") {
                    Text("\(sets.count) of \(prescribedSetCount) sets")
                }
                LabeledContent("Total hold") {
                    Text(String(format: "%.0fs", totalDurationSeconds))
                }
            } else {
                LabeledContent("Completed") {
                    Text("\(sets.count) of \(prescribedSetCount) sets")
                }
                LabeledContent("Total reps") {
                    Text("\(totalReps)")
                }
            }
        }
    }

    @ViewBuilder
    private var deleteSection: some View {
        Section {
            Button("Delete Session", role: .destructive) {
                showDeleteConfirmation = true
            }
        }
    }
}
