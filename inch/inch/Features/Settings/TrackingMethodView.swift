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
                    countingModeRow(for: enrolment)
                }
            } footer: {
                Text("Post-set: start a timer, then confirm how many reps you did. Real-time: tap the screen once per rep as you go.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Tracking Method")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func countingModeRow(for enrolment: ExerciseEnrolment) -> some View {
        let mode = viewModel.countingMode(for: enrolment)
        let name = enrolment.exerciseDefinition?.name ?? "Exercise"

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
