import SwiftUI
import InchShared

struct WatchTodayView: View {
    @Environment(WatchConnectivityService.self) private var watchConnectivity
    // Note: settings is NOT read here — WatchWorkoutView.init gains settings: in Task 8.
    // At Task 6 time, WatchWorkoutView still uses init(session:) — updated in Task 8.

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
                WatchWorkoutView(session: session)  // updated to session:settings: in Task 8
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
