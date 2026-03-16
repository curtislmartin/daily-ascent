import SwiftUI
import InchShared

struct WatchInSetView: View {
    let session: WatchSession
    let viewModel: WatchWorkoutViewModel
    let setStartDate: Date
    @Binding var elapsed: Int
    let showHeartRate: Bool
    let currentBPM: Int?

    @ScaledMetric private var elapsedFontSize: CGFloat = 32

    var body: some View {
        VStack(spacing: 6) {
            Text(session.exerciseName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text("Set \(viewModel.currentSet) of \(viewModel.totalSets)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Text(Duration.seconds(elapsed).formatted(.time(pattern: .minuteSecond)))
                .font(.system(size: elapsedFontSize, weight: .semibold, design: .monospaced))
            Text("Target: \(viewModel.targetReps)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Button("Done") { viewModel.endSet() }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .overlay(alignment: .topTrailing) {
            WatchHRBadge(showHeartRate: showHeartRate, currentBPM: currentBPM)
        }
        .task {
            while true {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return  // Cancelled when phase changes — exit cleanly
                }
                elapsed = Int(Date.now.timeIntervalSince(setStartDate))
            }
        }
    }
}
