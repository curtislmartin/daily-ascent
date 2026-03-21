import SwiftUI
import InchShared

struct ScheduleSettingsView: View {
    @Bindable var settings: UserSettings

    var body: some View {
        List {
            Section {
                Toggle("Show Conflict Warnings", isOn: $settings.showConflictWarnings)
            } footer: {
                Text("Warns you when test days or high-volume sessions conflict.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Schedule")
        .navigationBarTitleDisplayMode(.inline)
    }
}
