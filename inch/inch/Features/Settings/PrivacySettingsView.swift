import SwiftUI
import SwiftData
import InchShared
import WatchConnectivity

struct PrivacySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AnalyticsService.self) private var analytics
    var viewModel: SettingsViewModel

    @State private var showingDeleteHistoryConfirm = false
    @State private var showingResetConfirm = false

    private var settings: UserSettings? { viewModel.settings }

    var body: some View {
        List {
            consentSection
            analyticsSection
            iCloudSection
            dataSection
            Section("Legal") {
                Link("Privacy Policy", destination: URL(string: "https://curtislmartin.github.io/daily-ascent/privacy")!)
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

    private var analyticsSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { settings?.analyticsEnabled ?? false },
                set: { newValue in
                    settings?.analyticsEnabled = newValue
                    try? modelContext.save()
                    analytics.setEnabled(newValue)
                }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Share anonymous usage analytics")
                    Text("Helps improve the app. No personal data is collected. Cannot be linked to you.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Analytics")
        }
    }

    private var iCloudSection: some View {
        Section {
            Label("Syncing via iCloud", systemImage: "icloud")
                .foregroundStyle(.secondary)
        } header: {
            Text("iCloud")
        } footer: {
            Text("Your programme progress, workout history, and settings sync automatically across your Apple devices using your private iCloud account. Only you can access this data.")
        }
    }

    private var consentSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { settings?.motionDataUploadConsented ?? false },
                set: { newValue in
                    settings?.motionDataUploadConsented = newValue
                    settings?.consentDate = newValue ? .now : nil
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
            if WCSession.isSupported() {
                Toggle(isOn: Binding(
                    get: { settings?.dualDeviceRecordingEnabled ?? true },
                    set: { newValue in
                        settings?.dualDeviceRecordingEnabled = newValue
                        try? modelContext.save()
                    }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Record on Apple Watch")
                        Text("When your Watch is nearby and the app is open, both devices record simultaneously.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(settings?.motionDataUploadConsented == false)
            }
        } header: {
            Text("Sensor Data")
        } footer: {
            Text("While you work out, Daily Ascent records motion sensor data locally on your device. If sharing is enabled, your sensor data and optional profile details (age range, height, biological sex, and activity level) are uploaded anonymously to help train a rep-counting model. Different body types move differently — this context makes the model more accurate for everyone. No data is ever linked to your identity.")
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
                Text("Contributed sensor data is uploaded with a per-session random ID that groups sets from the same workout together, improving training data quality. This ID is not linked to your identity, your device, or any persistent identifier — it is generated fresh each workout and cannot be used to trace data back to you. Individual deletion is not possible.")
            }
        }
    }

}
