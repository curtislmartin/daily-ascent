import SwiftUI
import InchShared

struct ScheduleSettingsSection: View {
    @Bindable var settings: UserSettings

    var body: some View {
        Section {
            Toggle("Show Conflict Warnings", isOn: $settings.showConflictWarnings)
        } header: {
            Text("Schedule")
        } footer: {
            Text("Warns you when test days or high-volume sessions conflict.")
        }
    }
}
