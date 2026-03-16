import SwiftUI
import SwiftData
import InchShared

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = SettingsViewModel()
    @Environment(NotificationService.self) private var notifications

    var body: some View {
        List {
            if let s = viewModel.settings { AppearanceSectionView(settings: s) }
            workoutSection
            if let settings = viewModel.settings {
                NotificationsSettingsSection(
                    settings: settings,
                    isAuthorized: notifications.isAuthorized
                )
                ScheduleSettingsSection(settings: settings)
            }
            privacySection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.load(context: modelContext) }
        .task { await notifications.checkAuthorizationStatus() }
    }

    private var workoutSection: some View {
        Section("Workout") {
            NavigationLink("Rest Timers") {
                RestTimerSettingsView(viewModel: viewModel)
            }
            NavigationLink("Tracking Method") {
                TrackingMethodView(viewModel: viewModel)
            }
            NavigationLink("Manage Programs") {
                ManageEnrolmentsView()
            }
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

private struct AppearanceSectionView: View {
    @Bindable var settings: UserSettings
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Section("Appearance") {
            Picker("Theme", selection: $settings.appearanceMode) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            .pickerStyle(.segmented)
            .onChange(of: settings.appearanceMode) {
                try? modelContext.save()
            }
        }
    }
}
