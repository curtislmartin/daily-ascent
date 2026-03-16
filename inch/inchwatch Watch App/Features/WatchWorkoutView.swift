// inch/inchwatch Watch App/Features/WatchWorkoutView.swift
import SwiftUI
import WatchKit
import InchShared

struct WatchWorkoutView: View {
    let session: WatchSession

    var onStartNext: ((WatchSession) -> Void)?

    @Environment(WatchConnectivityService.self) private var watchConnectivity
    @Environment(WatchMotionRecordingService.self) private var motionRecording
    @Environment(WatchHealthService.self) private var healthService
    @Environment(WatchHistoryStore.self) private var historyStore
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: WatchWorkoutViewModel
    @State private var setStartDate: Date = .now
    @State private var elapsed: Int = 0
    @State private var hasAlerted: Bool = false

    init(session: WatchSession, settings: WatchSettings, onStartNext: ((WatchSession) -> Void)? = nil) {
        self.session = session
        self.onStartNext = onStartNext
        _viewModel = State(initialValue: WatchWorkoutViewModel(session: session, settings: settings))
    }

    private var remainingSessions: [WatchSession] {
        watchConnectivity.sessions.filter { $0.exerciseId != session.exerciseId }
    }

    var body: some View {
        Group {
            switch viewModel.phase {
            case .ready:
                WatchReadyView(session: session, viewModel: viewModel)
            case .inSet:
                if session.countingMode == "real_time" {
                    WatchRealTimeCountingView(
                        targetReps: viewModel.targetReps,
                        setNumber: viewModel.currentSet,
                        totalSets: viewModel.totalSets
                    ) { count in
                        viewModel.endSetRealTime(count: count)
                    }
                    .overlay(alignment: .topTrailing) {
                        WatchHRBadge(
                            showHeartRate: viewModel.showHeartRate,
                            currentBPM: healthService.currentBPM
                        )
                    }
                } else {
                    WatchInSetView(
                        session: session,
                        viewModel: viewModel,
                        setStartDate: setStartDate,
                        elapsed: $elapsed,
                        showHeartRate: viewModel.showHeartRate,
                        currentBPM: healthService.currentBPM
                    )
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
                    totalReps: viewModel.totalReps,
                    remainingSessions: remainingSessions
                ) { nextSession in
                    // Capture once — completionReport is computed and includes .now timestamp
                    let report = viewModel.completionReport
                    Task {
                        historyStore.record(report, exerciseName: session.exerciseName)
                        watchConnectivity.sendCompletionReport(report)
                        await healthService.endWorkout()
                        if let nextSession {
                            onStartNext?(nextSession)
                        }
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
                if motionRecording.isRecording,
                   case .confirming(let targetReps, let duration) = newPhase {
                    _ = motionRecording.stopAndTransfer(
                        exerciseId: session.exerciseId,
                        setNumber: viewModel.currentSet,
                        level: session.level,
                        dayNumber: session.dayNumber,
                        confirmedReps: viewModel.pendingRealTimeCount ?? targetReps,
                        durationSeconds: duration,
                        countingMode: session.countingMode
                    )
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
}
