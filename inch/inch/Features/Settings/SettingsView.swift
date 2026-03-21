import SwiftUI
import SwiftData
import InchShared

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = SettingsViewModel()

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
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.load(context: modelContext) }
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
