import SwiftUI
import SwiftData
import InchShared

enum AppTab: String, CaseIterable {
    case today, program, history
}

struct AppTabView: View {
    @State private var selectedTab: AppTab = .today
    @Query private var allSettings: [UserSettings]

    private var showSettingsBadge: Bool {
        guard let s = allSettings.first else { return false }
        return !s.hasDemographics
    }

    private var preferredColorScheme: ColorScheme? {
        switch allSettings.first?.appearanceMode {
        case "light": .light
        case "dark": .dark
        default: nil
        }
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
            Tab("Me", systemImage: "person", value: AppTab.history) {
                NavigationStack {
                    HistoryView()
                }
            }
        }
        .preferredColorScheme(preferredColorScheme)
    }
}
