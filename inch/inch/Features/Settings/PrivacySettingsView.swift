import SwiftUI
import SwiftData
import InchShared

struct PrivacySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    var viewModel: SettingsViewModel

    @State private var showingDeleteHistoryConfirm = false
    @State private var showingResetConfirm = false

    private var settings: UserSettings? { viewModel.settings }

    var body: some View {
        List {
            consentSection
            contributorSection
            dataSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Data & Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete all workout history?",
            isPresented: $showingDeleteHistoryConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete History", role: .destructive) {
                viewModel.deleteHistory(context: modelContext)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All completed sets and session records will be permanently deleted. Your programme progress is kept.")
        }
        .confirmationDialog(
            "Reset app to onboarding?",
            isPresented: $showingResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Reset Everything", role: .destructive) {
                viewModel.resetToOnboarding(context: modelContext)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All progress, history, and settings will be permanently deleted. You'll go through onboarding again.")
        }
    }

    private var consentSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { settings?.motionDataUploadConsented ?? false },
                set: { newValue in
                    settings?.motionDataUploadConsented = newValue
                    settings?.consentDate = newValue ? .now : nil
                    if newValue && (settings?.contributorId.isEmpty ?? true) {
                        settings?.contributorId = UUID().uuidString.lowercased()
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

    private var dataSection: some View {
        Section("Data") {
            Button("Delete Workout History", role: .destructive) {
                showingDeleteHistoryConfirm = true
            }
            Button("Reset App", role: .destructive) {
                showingResetConfirm = true
            }
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
        }
    }
}
