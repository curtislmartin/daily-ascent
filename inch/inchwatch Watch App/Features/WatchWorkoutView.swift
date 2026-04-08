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
    @State private var inboundSessionId: String = ""
    @State private var repCounter: RepCounter? = nil

    /// Exercises that use the watch wrist signal for auto-counting.
    private static let watchAutoCountedExercises: Set<String> = []

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
                        totalSets: viewModel.totalSets,
                        repCounter: repCounter
                    ) { count in
                        viewModel.endSetRealTime(count: count)
                    }
                    .overlay(alignment: .topTrailing) {
                        WatchHRBadge(
                            showHeartRate: viewModel.showHeartRate,
                            currentBPM: healthService.currentBPM
                        )
                    }
                } else if session.countingMode == "timed" {
                    WatchTimedSetView(
                        targetSeconds: viewModel.currentSetTarget
                    ) { actualDuration in
                        viewModel.endSetTimed(duration: actualDuration)
                    }
                } else if session.countingMode == "metronome" {
                    WatchMetronomeSetView(
                        targetReps: viewModel.targetReps,
                        beatIntervalSeconds: session.metronomeBeatIntervalSeconds,
                        beatPattern: session.metronomeBeatPattern,
                        sidesPerRep: session.metronomeSidesPerRep
                    ) { count in
                        viewModel.endSetRealTime(count: count)
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
                    // Capture report before any state changes — completedAt is .now
                    let report = viewModel.completionReport
                    // Sync work: immediate UI + delivery before any await
                    watchConnectivity.removeSession(exerciseId: session.exerciseId)
                    historyStore.record(report, exerciseName: session.exerciseName)
                    watchConnectivity.sendCompletionReport(report)
                    if let nextSession {
                        onStartNext?(nextSession)
                    } else {
                        dismiss()
                    }
                    // HealthKit cleanup runs in background — doesn't block UI
                    Task { await healthService.endWorkout() }
                }
            }
        }
        .background(.background)
        .ignoresSafeArea()
        .task {
            if Self.watchAutoCountedExercises.contains(session.exerciseId),
               let config = RepCountingConfig.config(for: session.exerciseId) {
                repCounter = RepCounter(config: config)
            }
            await healthService.startWorkout()
            for await trigger in watchConnectivity.recordingTriggers {
                switch trigger {
                case .start(let exerciseId, let setNumber, let sessionId):
                    guard exerciseId == session.exerciseId,
                          !motionRecording.isRecording else { break }
                    inboundSessionId = sessionId
                    motionRecording.startRecording(
                        exerciseId: exerciseId,
                        setNumber: setNumber,
                        sessionId: sessionId
                    )
                case .stop(let exerciseId, let setNumber):
                    guard exerciseId == session.exerciseId,
                          motionRecording.isRecording else { break }
                    _ = motionRecording.stopAndTransfer(
                        exerciseId: exerciseId,
                        setNumber: setNumber,
                        sessionId: inboundSessionId,
                        level: session.level,
                        dayNumber: session.dayNumber,
                        confirmedReps: 0,
                        durationSeconds: 0,
                        countingMode: session.countingMode
                    )
                    inboundSessionId = ""
                }
            }
        }
        .onChange(of: viewModel.phase) { _, newPhase in
            switch newPhase {
            case .inSet:
                // Reset elapsed timer — covers both manual Start and auto-advance after rest
                setStartDate = .now
                elapsed = 0
                // Use sessionId from iPhone if available (dual-device), else generate own
                let sid = inboundSessionId.isEmpty ? UUID().uuidString : inboundSessionId
                motionRecording.startRecording(
                    exerciseId: session.exerciseId,
                    setNumber: viewModel.currentSet,
                    sessionId: sid
                )
                if session.countingMode == "real_time" {
                    repCounter?.reset()
                    motionRecording.onSample = { [repCounter] ax, ay, az in
                        repCounter?.processSample(ax: ax, ay: ay, az: az)
                    }
                }
            case .confirming:
                if motionRecording.isRecording,
                   case .confirming(let targetReps, let duration) = newPhase {
                    _ = motionRecording.stopAndTransfer(
                        exerciseId: session.exerciseId,
                        setNumber: viewModel.currentSet,
                        sessionId: motionRecording.currentSessionId,
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
