import SwiftUI
import InchShared

struct WatchTodayView: View {
    @Environment(WatchConnectivityService.self) private var watchConnectivity
    @Environment(WatchMotionRecordingService.self) private var motionRecording

    @State private var activeSession: WatchSession?

    var body: some View {
        if watchConnectivity.sessions.isEmpty {
            restDayView
        } else {
            TabView {
                ForEach(watchConnectivity.sessions) { session in
                    exercisePage(for: session)
                }
            }
            .tabViewStyle(.page)
            .sheet(item: $activeSession) { session in
                WatchWorkoutView(session: session)
            }
        }
    }

    private func exercisePage(for session: WatchSession) -> some View {
        VStack(spacing: 8) {
            Spacer()
            Text(session.exerciseName)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Level \(session.level) · Day \(session.dayNumber)")
                .font(.caption)
                .foregroundStyle(.secondary)
            if session.isTest {
                Text("TEST DAY")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.2), in: Capsule())
                    .foregroundStyle(.orange)
            }
            Spacer()
            Button("Start") {
                activeSession = session
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
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
