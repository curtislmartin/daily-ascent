import SwiftUI
import SwiftData
import InchShared

struct SettingsView: View {
    // internal (not private) — accessed by DebugPanelSection extension in a separate file
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = SettingsViewModel()

    // internal (not private) — accessed by DebugPanelSection extension in a separate file
    #if DEBUG
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
            appSection
            #if DEBUG
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
        #if DEBUG
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
                WorkoutSoundsToggle(settings: settings)
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

    private var appSection: some View {
        Section {
            Link("Rate Daily Ascent", destination: URL(string: "https://apps.apple.com/app/id6760611343?action=write-review")!)
            ShareLink(
                item: URL(string: "https://apps.apple.com/us/app/daily-ascent/id6760611343")!,
                message: Text("I've been using Daily Ascent for structured bodyweight training — push-ups, pull-ups, squats and more with a smart scheduling system.")
            ) {
                Text("Share Daily Ascent")
            }
        }
    }
}

private struct WorkoutSoundsToggle: View {
    @Bindable var settings: UserSettings
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Toggle("Workout Sounds", isOn: $settings.workoutSoundsEnabled)
            .onChange(of: settings.workoutSoundsEnabled) {
                try? modelContext.save()
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
