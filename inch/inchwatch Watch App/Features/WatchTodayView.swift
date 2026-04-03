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
                        Image(systemName: exerciseIcon(for: session.exerciseId))
                            .font(.title3)
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

    private func exerciseIcon(for exerciseId: String) -> String {
        switch exerciseId {
        case "push_ups":         return "figure.strengthtraining.traditional"
        case "squats":           return "figure.gymnastics"
        case "pull_ups":         return "figure.climbing"
        case "hip_hinge":        return "figure.flexibility"
        case "dead_bugs":        return "figure.cooldown"
        case "spinal_extension": return "figure.pilates"
        case "plank":            return "figure.core.training"
        case "rows":             return "figure.rowing"
        case "dips":             return "figure.cross.training"
        default:                 return "figure.strengthtraining.functional"
        }
    }
}
