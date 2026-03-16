import SwiftUI
import InchShared

struct WatchTodayView: View {
    @Environment(WatchConnectivityService.self) private var watchConnectivity
    @Environment(WatchSettings.self) private var settings

    @State private var activeSession: WatchSession?

    var body: some View {
        if watchConnectivity.sessions.isEmpty {
            restDayView
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
                                .fontWeight(.bold)
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

    private var restDayView: some View {
        VStack(spacing: 8) {
            Image(systemName: "moon.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Rest Day")
                .font(.headline)
            if let syncDate = watchConnectivity.lastSyncDate {
                Text("Synced \(syncDate.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
