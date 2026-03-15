import SwiftUI
import InchShared

@main
struct inchwatch_Watch_AppApp: App {
    let watchConnectivity = WatchConnectivityService()

    var body: some Scene {
        WindowGroup {
            WatchTodayView()
                .environment(watchConnectivity)
                .task {
                    watchConnectivity.activate()
                    await watchConnectivity.processSessions()
                }
        }
    }
}
