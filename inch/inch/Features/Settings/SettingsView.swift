import SwiftUI
import SwiftData
import InchShared

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            List {
                workoutSection
                privacySection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task { viewModel.load(context: modelContext) }
        }
    }

    private var workoutSection: some View {
        Section("Workout") {
            NavigationLink("Rest Timers") {
                RestTimerSettingsView(viewModel: viewModel)
            }
            ForEach(viewModel.enrolments, id: \.persistentModelID) { enrolment in
                countingModeRow(for: enrolment)
            }
        }
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

    private var privacySection: some View {
        Section("Privacy") {
            NavigationLink("Data & Privacy") {
                PrivacySettingsView(viewModel: viewModel)
            }
        }
    }
}
