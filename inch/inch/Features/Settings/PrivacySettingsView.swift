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
            dataSection
            Section("Legal") {
                Link("Privacy Policy", destination: URL(string: "https://curtislmartin.github.io/inch/privacy")!)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Data & Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.load(context: modelContext) }
        .alert(
            "Delete all workout history?",
            isPresented: $showingDeleteHistoryConfirm
        ) {
            Button("Delete History", role: .destructive) {
                viewModel.deleteHistory(context: modelContext)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All completed sets and session records will be permanently deleted. Your programme progress is kept.")
        }
        .alert(
            "Reset app to onboarding?",
            isPresented: $showingResetConfirm
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
                    Text("Share data anonymously")
                    Text("Sensor data and optional profile details, used only to improve rep counting in this app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Sensor Data")
        } footer: {
            Text("While you work out, Inch records motion sensor data locally on your device. If sharing is enabled, your sensor data and optional profile details (age range, height, biological sex, and activity level) are uploaded anonymously to help train a rep-counting model. Different body types move differently — this context makes the model more accurate for everyone. No data is ever linked to your identity.")
        }
    }

    private var dataSection: some View {
        Section {
            Button("Delete Workout History", role: .destructive) {
                showingDeleteHistoryConfirm = true
            }
            Button("Reset App", role: .destructive) {
                showingResetConfirm = true
            }
        } header: {
            Text("Data")
        } footer: {
            if settings?.motionDataUploadConsented == true {
                Text("Contributed sensor data is uploaded with no identifier of any kind — not even a random ID. It cannot be linked back to you or your device, so individual deletion is not possible.")
            }
        }
    }

}
