import SwiftUI
import SwiftData
import InchShared

struct RestTimerSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    var viewModel: SettingsViewModel

    var body: some View {
        List {
            Section {
                ForEach(viewModel.enrolments, id: \.persistentModelID) { enrolment in
                    restTimerRow(for: enrolment)
                }
            } footer: {
                Text("Default rest times are based on the muscular demand of each exercise. Changes apply from your next set.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Rest Timers")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func restTimerRow(for enrolment: ExerciseEnrolment) -> some View {
        let seconds = viewModel.restSeconds(for: enrolment)
        let name = enrolment.exerciseDefinition?.name ?? "Exercise"
        let defaultSeconds = enrolment.exerciseDefinition?.defaultRestSeconds ?? 60

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body)
                if seconds != defaultSeconds {
                    Text("Default: \(defaultSeconds)s")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Stepper(
                "\(seconds)s",
                value: Binding(
                    get: { seconds },
                    set: { viewModel.setRestSeconds($0, for: enrolment, context: modelContext) }
                ),
                in: 15...300,
                step: 15
            )
            .fixedSize()
        }
    }
}
