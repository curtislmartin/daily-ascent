import SwiftUI
import InchShared

@main
struct inchwatch_Watch_AppApp: App {
    let watchConnectivity = WatchConnectivityService()
    let motionRecording = WatchMotionRecordingService()

    var body: some Scene {
        WindowGroup {
            WatchTodayView()
                .environment(watchConnectivity)
                .environment(motionRecording)
                .task {
                    watchConnectivity.activate()
                    await watchConnectivity.processSessions()
                }
        }
    }
}
