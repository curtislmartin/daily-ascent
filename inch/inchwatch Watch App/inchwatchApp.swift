import SwiftUI
import InchShared

@main
struct inchwatch_Watch_AppApp: App {
    let watchConnectivity = WatchConnectivityService()
    let motionRecording = WatchMotionRecordingService()
    let healthService = WatchHealthService()
    let historyStore = WatchHistoryStore()
    let settings = WatchSettings()

    var body: some Scene {
        WindowGroup {
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
        }
    }
}
