import SwiftUI
import InchShared

struct WatchWorkoutView: View {
    let session: WatchSession

    @Environment(WatchConnectivityService.self) private var watchConnectivity
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: WatchWorkoutViewModel
    @State private var elapsed: Int = 0

    init(session: WatchSession) {
        self.session = session
        _viewModel = State(initialValue: WatchWorkoutViewModel(session: session))
    }

    var body: some View {
        Group {
            switch viewModel.phase {
            case .ready:
                readyView
            case .inSet:
                inSetView
            case .confirming(let targetReps, _):
                WatchPostSetView(targetReps: targetReps) { actual in
                    viewModel.confirmSet(actual: actual)
                }
            case .resting(let seconds):
                WatchRestTimerView(restSeconds: seconds) {
                    viewModel.finishRest()
                }
            case .complete:
                WatchExerciseCompleteView(
                    exerciseName: session.exerciseName,
                    totalReps: viewModel.totalReps
                ) {
                    watchConnectivity.sendCompletionReport(viewModel.completionReport)
                    dismiss()
                }
            }
        }
        .navigationTitle(session.exerciseName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var readyView: some View {
        VStack(spacing: 8) {
            Text("Set \(viewModel.currentSet) of \(viewModel.totalSets)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(viewModel.targetReps)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
            Text("reps")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Start Set") {
                elapsed = 0
                viewModel.startSet()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var inSetView: some View {
        VStack(spacing: 8) {
            Text("Set \(viewModel.currentSet) of \(viewModel.totalSets)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(Duration.seconds(elapsed).formatted(.time(pattern: .minuteSecond)))
                .font(.system(size: 36, weight: .semibold, design: .monospaced))
            Text("Target: \(viewModel.targetReps)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("End Set") { viewModel.endSet() }
                .buttonStyle(.bordered)
        }
        .task {
            while true {
                try? await Task.sleep(for: .seconds(1))
                elapsed += 1
            }
        }
    }
}
