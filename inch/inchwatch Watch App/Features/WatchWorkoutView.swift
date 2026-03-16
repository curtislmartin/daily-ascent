// inch/inchwatch Watch App/Features/WatchWorkoutView.swift
import SwiftUI
import WatchKit
import InchShared

struct WatchWorkoutView: View {
    let session: WatchSession

    @Environment(WatchConnectivityService.self) private var watchConnectivity
    @Environment(WatchMotionRecordingService.self) private var motionRecording
    @Environment(WatchHealthService.self) private var healthService
    @Environment(WatchHistoryStore.self) private var historyStore
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: WatchWorkoutViewModel
    @State private var setStartDate: Date = .now
    @State private var elapsed: Int = 0
    @State private var hasAlerted: Bool = false

    init(session: WatchSession, settings: WatchSettings) {
        self.session = session
        _viewModel = State(initialValue: WatchWorkoutViewModel(session: session, settings: settings))
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
                    .overlay(alignment: .topTrailing) { hrBadge }
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
                    Task {
                        historyStore.record(viewModel.completionReport, exerciseName: session.exerciseName)
                        watchConnectivity.sendCompletionReport(viewModel.completionReport)
                        await healthService.endWorkout()
                        dismiss()
                    }
                }
            }
        }
        .background(.background)
        .ignoresSafeArea()
        .onChange(of: viewModel.phase) { _, newPhase in
            switch newPhase {
            case .inSet:
                // Reset elapsed timer — covers both manual Start and auto-advance after rest
                setStartDate = .now
                elapsed = 0
                motionRecording.startRecording(exerciseId: session.exerciseId, setNumber: viewModel.currentSet)
            case .confirming:
                if motionRecording.isRecording {
                    _ = motionRecording.stopAndTransfer(exerciseId: session.exerciseId, setNumber: viewModel.currentSet)
                }
            default:
                break
            }
        }
        .onChange(of: healthService.currentBPM) { _, bpm in
            guard let bpm else {
                hasAlerted = false
                return
            }
            let threshold = viewModel.heartRateAlertBPM
            if threshold > 0 && bpm >= threshold && !hasAlerted {
                WKInterfaceDevice.current().play(.notification)
                hasAlerted = true
            } else if threshold > 0 && bpm < threshold {
                hasAlerted = false
            }
        }
    }

    @ViewBuilder private var hrBadge: some View {
        if viewModel.showHeartRate, let bpm = healthService.currentBPM {
            Text("♥ \(bpm)")
                .font(.caption2)
                .foregroundStyle(.red)
                .padding(4)
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
                // Only call startWorkout() on the first set — guard against duplicate HKWorkoutSession starts
                if viewModel.completedSets.isEmpty {
                    Task { await healthService.startWorkout() }
                }
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
        .overlay(alignment: .topTrailing) { hrBadge }
        .task {
            while true {
                try? await Task.sleep(for: .seconds(1))
                elapsed = Int(Date.now.timeIntervalSince(setStartDate))
            }
        }
    }
}
