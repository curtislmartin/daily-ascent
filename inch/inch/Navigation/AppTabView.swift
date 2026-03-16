import SwiftUI
import SwiftData
import InchShared

enum AppTab: String, CaseIterable {
    case today, program, history, settings
}

struct AppTabView: View {
    @State private var selectedTab: AppTab = .today
    @Query private var allSettings: [UserSettings]

    private var showSettingsBadge: Bool {
        guard let s = allSettings.first else { return false }
        return s.motionDataUploadConsented && !s.hasDemographics
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Today", systemImage: "calendar", value: AppTab.today) {
                NavigationStack {
                    TodayView()
                }
            }
            Tab("Program", systemImage: "chart.bar", value: AppTab.program) {
                NavigationStack {
                    ProgramView()
                        .withProgramDestinations()
                }
            }
            Tab("History", systemImage: "clock", value: AppTab.history) {
                NavigationStack {
                    HistoryView()
                }
            }
            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                NavigationStack {
                    SettingsView()
                }
            }
            .badge(showSettingsBadge ? 1 : 0)
        }
    }
}
