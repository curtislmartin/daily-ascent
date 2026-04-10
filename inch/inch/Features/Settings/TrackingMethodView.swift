import SwiftUI
import SwiftData
import InchShared

struct TrackingMethodView: View {
    @Environment(\.modelContext) private var modelContext
    var viewModel: SettingsViewModel

    var body: some View {
        List {
            Section {
                ForEach(viewModel.enrolments, id: \.persistentModelID) { enrolment in
                    row(for: enrolment)
                }
            } footer: {
                Text("Post-set: start a timer, then confirm how many reps you did. Real-time: tap the screen once per rep as you go. Metronome and timed exercises have a fixed tracking method.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Tracking Method")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func row(for enrolment: ExerciseEnrolment) -> some View {
        let name = enrolment.exerciseDefinition?.name ?? "Exercise"
        let intrinsicMode = enrolment.exerciseDefinition?.countingMode ?? .postSetConfirmation

        switch intrinsicMode {
        case .metronome:
            LabeledContent(name) {
                Text("Metronome").foregroundStyle(.secondary)
            }
        case .timed:
            LabeledContent(name) {
                Text("Timed").foregroundStyle(.secondary)
            }
        case .postSetConfirmation, .realTime:
            pickerRow(name: name, enrolment: enrolment)
        }
    }

    private func pickerRow(name: String, enrolment: ExerciseEnrolment) -> some View {
        let mode = viewModel.countingMode(for: enrolment)
        return Picker(name, selection: Binding(
            get: { mode },
            set: { viewModel.setCountingMode($0, for: enrolment, context: modelContext) }
        )) {
            Text("Post-set").tag(CountingMode.postSetConfirmation)
            Text("Real-time").tag(CountingMode.realTime)
        }
        .pickerStyle(.menu)
    }
}
