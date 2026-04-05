import SwiftUI
import InchShared

struct WatchTodayView: View {
    @Environment(WatchConnectivityService.self) private var watchConnectivity
    @Environment(WatchSettings.self) private var settings

    @State private var activeSession: WatchSession?
    @State private var pendingNextSession: WatchSession?

    var body: some View {
        if watchConnectivity.sessions.isEmpty {
            WatchRestDayView(lastSyncDate: watchConnectivity.lastSyncDate)
        } else {
            List(watchConnectivity.sessions) { session in
                Button {
                    activeSession = session
                } label: {
                    HStack(alignment: .center, spacing: 8) {
                        exerciseImage(for: session.exerciseId)
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
            }
            .navigationTitle("Today")
            .sheet(item: $activeSession) { session in
                WatchWorkoutView(session: session, settings: settings) { next in
                    pendingNextSession = next
                    activeSession = nil
                }
            }
            .onChange(of: activeSession) { _, newValue in
                guard newValue == nil, let next = pendingNextSession else { return }
                pendingNextSession = nil
                activeSession = next
            }
        }
    }

    @ViewBuilder
    private func exerciseImage(for exerciseId: String) -> some View {
        switch exerciseId {
        case "push_ups", "plank":
            Image("push_ups_icon")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
        case "hip_hinge":
            Image("glute_bridges_icon")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
        default:
            Image(systemName: exerciseIcon(for: exerciseId))
                .font(.title3)
        }
    }

    private func exerciseIcon(for exerciseId: String) -> String {
        switch exerciseId {
        case "squats":           return "figure.cross.training"
        case "pull_ups":         return "figure.play"
        case "dead_bugs":        return "figure.core.training"
        case "spinal_extension": return "figure.yoga"
        case "rows":             return "figure.indoor.rowing"
        case "dips":             return "figure.rolling"
        default:                 return "figure.strengthtraining.functional"
        }
    }
}
