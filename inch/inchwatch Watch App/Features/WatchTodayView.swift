import SwiftUI
import InchShared

struct WatchTodayView: View {
    @Environment(WatchConnectivityService.self) private var watchConnectivity

    var body: some View {
        NavigationStack {
            Group {
                if watchConnectivity.sessions.isEmpty {
                    restDayView
                } else {
                    sessionList
                }
            }
            .navigationTitle("Today")
            .navigationDestination(for: String.self) { exerciseId in
                if let session = watchConnectivity.sessions.first(where: { $0.exerciseId == exerciseId }) {
                    WatchWorkoutView(session: session)
                }
            }
        }
    }

    private var sessionList: some View {
        List(watchConnectivity.sessions, id: \.exerciseId) { session in
            NavigationLink(value: session.exerciseId) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.exerciseName)
                        .font(.headline)
                    Text("L\(session.level) · Day \(session.dayNumber)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
