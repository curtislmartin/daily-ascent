import SwiftUI
import InchShared

struct WatchTodayView: View {
    @Environment(WatchConnectivityService.self) private var watchConnectivity
    @Environment(WatchSettings.self) private var settings

    @State private var activeSession: WatchSession?

    var body: some View {
        if watchConnectivity.sessions.isEmpty {
            WatchRestDayView(lastSyncDate: watchConnectivity.lastSyncDate)
        } else {
            List(watchConnectivity.sessions) { session in
                Button {
                    activeSession = session
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.exerciseName)
                            .font(.headline)
                        Text("Level \(session.level) · Day \(session.dayNumber)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if session.isTest {
                            Text("TEST DAY")
                                .font(.caption2)
                                .bold()
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .sheet(item: $activeSession) { session in
                WatchWorkoutView(session: session, settings: settings)
            }
        }
    }
}
