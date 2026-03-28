import SwiftUI
import InchShared
import WidgetKit

@main
struct inchwatch_Watch_AppApp: App {
    let watchConnectivity = WatchConnectivityService()
    let motionRecording = WatchMotionRecordingService()
    let healthService = WatchHealthService()
    let historyStore = WatchHistoryStore()
    let settings = WatchSettings()

    var body: some Scene {
        WindowGroup {
            // TODO: Replace .tabItem with Tab {} API when minimum deployment target is raised to watchOS 11+
            TabView {
                WatchTodayView()
                    .tabItem { Label("Today", systemImage: "figure.strengthtraining.traditional") }

                WatchHistoryView()
                    .tabItem { Label("History", systemImage: "clock") }

                WatchSettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape") }
            }
            .environment(watchConnectivity)
            .environment(motionRecording)
            .environment(healthService)
            .environment(historyStore)
            .environment(settings)
            .task {
                watchConnectivity.activate()
                await watchConnectivity.processSessions()
            }
            .task {
                for await entry in watchConnectivity.historyEntries {
                    historyStore.record(entry)
                    writeComplicationData()
                }
            }
            .onChange(of: watchConnectivity.sessions) { _, _ in writeComplicationData() }
        }
    }

    private func writeComplicationData() {
        let todayStart = Calendar.current.startOfDay(for: .now)
        let completedToday = historyStore.entries.filter { $0.completedAt >= todayStart }.count
        UserDefaults.standard.set(watchConnectivity.sessions.count, forKey: "watch.complication.dueCount")
        UserDefaults.standard.set(completedToday, forKey: "watch.complication.completedToday")
        UserDefaults.standard.set(watchConnectivity.sessions.first?.exerciseName, forKey: "watch.complication.nextExerciseName")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
