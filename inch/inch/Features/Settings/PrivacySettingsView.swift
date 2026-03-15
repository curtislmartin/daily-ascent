import SwiftUI
import SwiftData
import InchShared

struct PrivacySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    var viewModel: SettingsViewModel

    @State private var showingResetConfirm = false

    private var settings: UserSettings? { viewModel.settings }

    var body: some View {
        List {
            consentSection
            contributorSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Data & Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var consentSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { settings?.motionDataUploadConsented ?? false },
                set: { newValue in
                    settings?.motionDataUploadConsented = newValue
                    settings?.consentDate = newValue ? .now : nil
                    if newValue && (settings?.contributorId.isEmpty ?? true) {
                        settings?.contributorId = UUID().uuidString
                    }
                    try? modelContext.save()
                }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Share motion data anonymously")
                    Text("Helps improve automatic rep counting.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } footer: {
            Text("Motion sensor data is always recorded locally during workouts. Enabling sharing sends anonymised accelerometer and gyroscope data to help train rep-counting models for this app.")
        }
    }

    private var contributorSection: some View {
        Section("Contributor") {
            if let id = settings?.contributorId, !id.isEmpty {
                LabeledContent("Contributor ID") {
                    Text(id.prefix(8) + "…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospaced()
                }
            }

            Button("Reset Contributor ID", role: .destructive) {
                showingResetConfirm = true
            }
            .confirmationDialog(
                "Reset Contributor ID?",
                isPresented: $showingResetConfirm,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    settings?.contributorId = UUID().uuidString
                    try? modelContext.save()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("A new anonymous ID will be generated. Previously contributed data remains anonymous and cannot be linked to the new ID.")
            }
        }
    }
}
