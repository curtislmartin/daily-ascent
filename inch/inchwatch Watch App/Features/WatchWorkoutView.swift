import SwiftUI
import InchShared

struct WatchWorkoutView: View {
    let session: WatchSession

    @Environment(WatchConnectivityService.self) private var watchConnectivity
    @Environment(WatchMotionRecordingService.self) private var motionRecording
    @Environment(WatchSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: WatchWorkoutViewModel
    @State private var setStartDate: Date = .now
    @State private var elapsed: Int = 0

    init(session: WatchSession) {
        self.session = session
        let defaultSettings = WatchSettings()
        _viewModel = State(initialValue: WatchWorkoutViewModel(session: session, settings: defaultSettings))
    }

    var body: some View {
        Group {
            switch viewModel.phase {
            case .ready:
                readyView
            case .inSet:
                if session.countingMode == "real_time" {
                    WatchRealTimeCountingView(
                        targetReps: viewModel.targetReps,
                        setNumber: viewModel.currentSet,
                        totalSets: viewModel.totalSets
                    ) { count in
                        viewModel.endSetRealTime(count: count)
                    }
                } else {
                    inSetView
                }
            case .confirming(let targetReps, _):
                WatchPostSetView(
                    targetReps: targetReps,
                    initialReps: viewModel.pendingRealTimeCount
                ) { actual in
                    viewModel.clearPendingRealTimeCount()
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
        .background(.background)
        .ignoresSafeArea()
        .onChange(of: viewModel.phase) { _, newPhase in
            switch newPhase {
            case .inSet:
                motionRecording.startRecording(exerciseId: session.exerciseId, setNumber: viewModel.currentSet)
            case .confirming:
                if motionRecording.isRecording {
                    _ = motionRecording.stopAndTransfer(exerciseId: session.exerciseId, setNumber: viewModel.currentSet)
                }
            default:
                break
            }
        }
    }

    private var readyView: some View {
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
            Text("\(viewModel.targetReps)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
            Text("reps")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Button("Start") {
                setStartDate = .now
                elapsed = 0
                viewModel.startSet()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var inSetView: some View {
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
                .font(.system(size: 32, weight: .semibold, design: .monospaced))
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
        .task {
            while true {
                try? await Task.sleep(for: .seconds(1))
                elapsed = Int(Date.now.timeIntervalSince(setStartDate))
            }
        }
    }
}
