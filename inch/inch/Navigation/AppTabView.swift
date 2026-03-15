import SwiftUI

enum AppTab: String, CaseIterable {
    case today, program, history
}

struct AppTabView: View {
    @State private var selectedTab: AppTab = .today

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
        }
    }
}
