import SwiftUI
import SwiftData
import InchShared

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = SettingsViewModel()
    @Environment(NotificationService.self) private var notifications

    var body: some View {
        List {
            appearanceSection
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

    private var appearanceSection: some View {
        Section("Appearance") {
            if let settings = viewModel.settings {
                Picker("Theme", selection: Binding(
                    get: { settings.appearanceMode },
                    set: { settings.appearanceMode = $0; try? modelContext.save() }
                )) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
            }
        }
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
