import SwiftUI
import SwiftData
import InchShared

struct SettingsView: View {
    // internal (not private) — accessed by DebugPanelSection extension in a separate file
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = SettingsViewModel()

    // internal (not private) — accessed by DebugPanelSection extension in a separate file
    #if DEBUG || TESTFLIGHT
    @State var debugViewModel = DebugViewModel()
    @Environment(NotificationService.self) var notificationService
    @Environment(WatchConnectivityService.self) var watchConnectivity
    @Environment(HealthKitService.self) var healthKit
    @Environment(DataUploadService.self) var dataUpload
    #endif

    private var showAboutMeBadge: Bool {
        guard let s = viewModel.settings else { return false }
        return !s.hasDemographics
    }

    var body: some View {
        List {
            profileSection
            programSection
            workoutSection
            if let settings = viewModel.settings {
                generalSection(settings: settings)
            }
            privacySection
            #if DEBUG || TESTFLIGHT
            debugContent
            #endif
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Close", systemImage: "xmark") {
                    dismiss()
                }
            }
        }
        .task { viewModel.load(context: modelContext) }
        #if DEBUG || TESTFLIGHT
        .alert(debugViewModel.alertTitle, isPresented: $debugViewModel.showAlert) {
            Button("OK") {}
        } message: {
            Text(debugViewModel.alertMessage)
        }
        .alert(debugViewModel.dangerTitle, isPresented: $debugViewModel.showDangerConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Confirm", role: .destructive) {
                debugViewModel.pendingDangerAction?()
            }
        } message: {
            Text(debugViewModel.dangerMessage)
        }
        #endif
    }

    private var profileSection: some View {
        Section {
            NavigationLink("About Me") {
                AboutMeView(viewModel: viewModel)
            }
            .badge(showAboutMeBadge ? Text("") : nil)
        }
    }

    private var programSection: some View {
        Section("Program") {
            NavigationLink("Manage Exercises") {
                ManageEnrolmentsView()
            }
        }
    }

    private var workoutSection: some View {
        Section("Workout") {
            NavigationLink("Rest Timers") {
                RestTimerSettingsView(viewModel: viewModel)
            }
            NavigationLink("Counting Method") {
                TrackingMethodView(viewModel: viewModel)
            }
            if let settings = viewModel.settings {
                NavigationLink("Timed Exercises") {
                    TimedExerciseSettingsView(settings: settings)
                }
            }
        }
    }

    private func generalSection(settings: UserSettings) -> some View {
        Section("General") {
            NavigationLink("Notifications") {
                NotificationsSettingsView(settings: settings)
            }
            NavigationLink("Schedule") {
                ScheduleSettingsView(settings: settings)
            }
            AppearancePicker(settings: settings)
        }
    }

    private var privacySection: some View {
        Section("Privacy") {
            NavigationLink("Data & Privacy") {
                PrivacySettingsView(viewModel: viewModel)
            }
        }
    }
}

private struct AppearancePicker: View {
    @Bindable var settings: UserSettings
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Picker("Appearance", selection: $settings.appearanceMode) {
            Text("System").tag("system")
            Text("Light").tag("light")
            Text("Dark").tag("dark")
        }
        .onChange(of: settings.appearanceMode) {
            try? modelContext.save()
        }
    }
}
