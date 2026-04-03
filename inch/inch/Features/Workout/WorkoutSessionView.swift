import SwiftUI
import SwiftData
import InchShared

struct WorkoutSessionView: View {
    let enrolmentId: PersistentIdentifier

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AnalyticsService.self) private var analytics
    @Environment(HealthKitService.self) private var healthKit
    @Environment(MotionRecordingService.self) private var motionRecording
    @Environment(DataUploadService.self) private var dataUpload
    @Environment(NotificationService.self) private var notifications
    @Environment(WatchConnectivityService.self) private var watchConnectivity

    @Query private var allSettings: [UserSettings]
    private var sensorConsented: Bool { allSettings.first?.motionDataUploadConsented ?? false }
    private var settings: UserSettings? { allSettings.first }
    private var dualRecordingEnabled: Bool { allSettings.first?.dualDeviceRecordingEnabled ?? true }

    private var exerciseId: String {
        viewModel.enrolment?.exerciseDefinition?.exerciseId ?? ""
    }

    private var phoneHint: (message: String, icon: String)? {
        switch exerciseId {
        case "dead_bugs", "squats":
            return ("Hold your phone for better tracking", "hand.raised.fill")
        case "pull_ups", "push_ups", "hip_hinge", "dips", "rows":
            return ("Put your phone in your pocket for better tracking", "iphone")
        default:
            return nil
        }
    }

    private var shouldShowHoldPhoneHint: Bool {
        showHoldPhoneHint &&
        phoneHint != nil &&
        !watchConnectivity.isWatchReachable &&
        viewModel.currentSetIndex == 0
    }

    @State private var viewModel: WorkoutViewModel
    @State private var repCounter: RepCounter? = nil
    @State private var pendingRecordingURL: URL?

    private static let phoneAutoCountedExercises: Set<String> = [
        "push_ups", "pull_ups", "squats", "hip_hinge", "dead_bugs"
    ]
    @State private var realTimeSetStartDate: Date?
    @State private var showingQuitConfirm = false
    @State private var sessionId: String = ""
    @State private var showHoldPhoneHint = true
    @State private var showNudge = false
    @State private var showTier3Intro = false
    @State private var setStartOrientation: String = ""

    init(enrolmentId: PersistentIdentifier) {
        self.enrolmentId = enrolmentId
        _viewModel = State(initialValue: WorkoutViewModel(enrolmentId: enrolmentId))
    }

    private var shouldWarnOnBack: Bool {
        switch viewModel.phase {
        case .loading, .complete:
            false
        case .inSet, .inRealTimeSet, .preparingTimedSet, .inTimedSet:
            true
        default:
            viewModel.currentSetIndex > 0
        }
    }

    var body: some View {
        Group {
            switch viewModel.phase {
            case .loading:
                ProgressView()
            case .ready:
                readyView
            case .inSet:
                inSetView
            case .inRealTimeSet:
                realTimeSetView
            case .confirming(let targetReps, let duration):
                PostSetConfirmationView(targetReps: targetReps, duration: duration) { actual in
                    let url = pendingRecordingURL
                    pendingRecordingURL = nil
                    viewModel.confirmSet(actual: actual, context: modelContext, recordingURL: url, duration: duration)
                }
            case .resting(let seconds):
                RestTimerView(
                    totalSeconds: seconds,
                    nextSetReps: viewModel.isTimedExercise ? nil : viewModel.prescription?.sets[safe: viewModel.currentSetIndex],
                    nextSetDuration: viewModel.isTimedExercise ? viewModel.currentTargetReps : nil
                ) {
                    viewModel.finishRest()
                }
            case .preparingTimedSet(let targetSeconds):
                PreSetCountdownView(
                    countdownSeconds: settings?.timedPrepCountdownSeconds ?? 5,
                    holdDurationSeconds: targetSeconds,
                    onStart: {
                        viewModel.countdownComplete()
                    }
                )
            case .inTimedSet(let targetSeconds):
                TimedSetView(targetSeconds: targetSeconds) { actualDuration in
                    let url = sensorConsented ? motionRecording.stopRecording() : nil
                    if dualRecordingEnabled {
                        let exerciseId = viewModel.enrolment?.exerciseDefinition?.exerciseId ?? ""
                        watchConnectivity.sendRecordingStop(
                            exerciseId: exerciseId,
                            setNumber: viewModel.currentSetIndex + 1
                        )
                    }
                    viewModel.completeTimedSet(
                        actualDuration: actualDuration,
                        context: modelContext,
                        recordingURL: url
                    )
                }
                .id(viewModel.currentSetIndex)
            case .complete:
                ExerciseCompleteView(
                    exerciseName: viewModel.exerciseName,
                    totalReps: viewModel.sessionTotalReps,
                    previousSessionReps: viewModel.previousSessionReps,
                    nextDate: viewModel.enrolment?.nextScheduledDate,
                    onDone: { dismiss() },
                    achievements: viewModel.pendingAchievements,
                    adaptationMessage: viewModel.adaptationMessage,
                    showMoveOnAnyway: viewModel.showMoveOnAnyway,
                    onRatingSubmitted: viewModel.isTestDay ? nil : { rating in
                        viewModel.submitDifficultyRating(rating, context: modelContext)
                    },
                    onMoveOnAnyway: {
                        viewModel.moveOnAnyway(context: modelContext)
                    }
                )
            }
        }
        .navigationTitle(viewModel.exerciseName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(shouldWarnOnBack)
        .toolbar {
            if shouldWarnOnBack {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingQuitConfirm = true
                    } label: {
                        Text("Quit Workout")
                    }
                }
            }
        }
        .alert("Quit workout?", isPresented: $showingQuitConfirm) {
            Button("Quit Workout", role: .destructive) {
                analytics.record(AnalyticsEvent(
                    name: "workout_abandoned",
                    properties: .workoutAbandoned(
                        exerciseId: viewModel.enrolment?.exerciseDefinition?.exerciseId ?? "",
                        level: viewModel.enrolment?.currentLevel ?? 0,
                        dayNumber: viewModel.enrolment?.currentDay ?? 0,
                        setsCompleted: viewModel.currentSetIndex,
                        setsTotal: viewModel.totalSets
                    )
                ))
                let url = motionRecording.stopRecording()
                if let url { try? FileManager.default.removeItem(at: url) }
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your progress so far won't be saved.")
        }
        .sheet(isPresented: $showTier3Intro, onDismiss: markExerciseSeen) {
            NavigationStack {
                ExerciseInfoSheet(
                    exerciseId: exerciseId,
                    exerciseName: viewModel.exerciseName,
                    level: viewModel.enrolment?.currentLevel ?? 1
                )
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Got it") { showTier3Intro = false }
                    }
                }
            }
        }
        .task {
            sessionId = UUID().uuidString
            viewModel.configure(analytics: analytics)
            viewModel.load(context: modelContext)
            let tier3Exercises = ["dead_bugs", "glute_bridges"]
            if tier3Exercises.contains(exerciseId),
               let s = settings,
               !s.seenExerciseInfo.contains(exerciseId) {
                showTier3Intro = true
            } else if let s = settings, !s.seenExerciseInfo.contains(exerciseId) {
                showNudge = true
            }
            let id = viewModel.enrolment?.exerciseDefinition?.exerciseId ?? ""
            if repCounter == nil, Self.phoneAutoCountedExercises.contains(id),
               let config = RepCountingConfig.config(for: id) {
                repCounter = RepCounter(config: config)
            }
            if sensorConsented, !motionRecording.isRecording {
                repCounter?.reset()
                motionRecording.onSample = { [repCounter] ax, ay, az in
                    repCounter?.processSample(ax: ax, ay: ay, az: az)
                }
                motionRecording.startRecording(
                    exerciseId: id,
                    setNumber: viewModel.currentSetIndex + 1,
                    sessionId: sessionId,
                    context: modelContext
                )
            }
            await healthKit.requestAuthorization()
        }
        .onChange(of: viewModel.phase) { _, newPhase in
            switch newPhase {
            case .ready:
                if sensorConsented, !motionRecording.isRecording {
                    let exerciseId = viewModel.enrolment?.exerciseDefinition?.exerciseId ?? ""
                    repCounter?.reset()
                    motionRecording.onSample = { [repCounter] ax, ay, az in
                        repCounter?.processSample(ax: ax, ay: ay, az: az)
                    }
                    motionRecording.startRecording(
                        exerciseId: exerciseId,
                        setNumber: viewModel.currentSetIndex + 1,
                        sessionId: sessionId,
                        context: modelContext
                    )
                }
            case .inRealTimeSet:
                showHoldPhoneHint = false
                realTimeSetStartDate = .now
                if sensorConsented {
                    let exerciseId = viewModel.enrolment?.exerciseDefinition?.exerciseId ?? ""
                    if dualRecordingEnabled {
                        watchConnectivity.sendRecordingStart(
                            exerciseId: exerciseId,
                            setNumber: viewModel.currentSetIndex + 1,
                            sessionId: sessionId
                        )
                    }
                }
            case .inSet:
                showHoldPhoneHint = false
                if sensorConsented {
                    let exerciseId = viewModel.enrolment?.exerciseDefinition?.exerciseId ?? ""
                    if dualRecordingEnabled {
                        watchConnectivity.sendRecordingStart(
                            exerciseId: exerciseId,
                            setNumber: viewModel.currentSetIndex + 1,
                            sessionId: sessionId
                        )
                    }
                }
            case .inTimedSet:
                showHoldPhoneHint = false
                if sensorConsented {
                    let exerciseId = viewModel.enrolment?.exerciseDefinition?.exerciseId ?? ""
                    if dualRecordingEnabled {
                        watchConnectivity.sendRecordingStart(
                            exerciseId: exerciseId,
                            setNumber: viewModel.currentSetIndex + 1,
                            sessionId: sessionId
                        )
                    }
                }
            case .confirming:
                if motionRecording.isRecording {
                    pendingRecordingURL = motionRecording.stopRecording()
                }
                if dualRecordingEnabled {
                    let exerciseId = viewModel.enrolment?.exerciseDefinition?.exerciseId ?? ""
                    watchConnectivity.sendRecordingStop(
                        exerciseId: exerciseId,
                        setNumber: viewModel.currentSetIndex + 1
                    )
                }
            case .complete:
                dataUpload.scheduleBGUpload()
                watchConnectivity.sendHistoryEntry(
                    exerciseName: viewModel.exerciseName,
                    level: viewModel.completedLevel,
                    dayNumber: viewModel.completedDay,
                    totalReps: viewModel.sessionTotalReps,
                    setCount: viewModel.totalSets,
                    completedAt: viewModel.sessionDate
                )
                let start = viewModel.sessionDate
                let exerciseId = viewModel.enrolment?.exerciseDefinition?.exerciseId ?? ""
                Task {
                    await healthKit.saveWorkout(
                        startDate: start,
                        endDate: .now,
                        totalEnergyBurned: nil,
                        metadata: ["exerciseId": exerciseId]
                    )
                }
                if let settings {
                    Task {
                        // Request permission (UNUserNotificationCenter is idempotent — shows prompt only once)
                        await notifications.requestPermission()
                        // Cancel today's streak-protection notification (just completed a workout)
                        notifications.cancelTodayStreakProtection()
                        // Refresh upcoming notification schedule
                        await notifications.refresh(context: modelContext, settings: settings)
                        // Post level-unlock notification if the test was just passed
                        if viewModel.didAdvanceLevel, settings.levelUnlockNotificationEnabled {
                            notifications.postLevelUnlock(
                                exerciseName: viewModel.exerciseName,
                                newLevel: viewModel.newLevel,
                                startsIn: SchedulingEngine.interLevelGapDays
                            )
                        }
                    }
                }
            default:
                break
            }
        }
        .onDisappear {
            if motionRecording.isRecording {
                let url = motionRecording.stopRecording()
                if let url { try? FileManager.default.removeItem(at: url) }
            }
        }
    }

    private var readyView: some View {
        VStack(spacing: 32) {
            if shouldShowHoldPhoneHint, let hint = phoneHint {
                HStack(spacing: 10) {
                    Image(systemName: hint.icon)
                        .foregroundStyle(.secondary)
                    Text(hint.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        showHoldPhoneHint = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            }

            if showNudge && viewModel.currentSetIndex == 0 {
                ExerciseNudgeBanner(exerciseName: viewModel.exerciseName) {
                    dismissNudge()
                }
            }

            if viewModel.prescriptionOverrideMultiplier != nil {
                Text("Lighter session today")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 12).padding(.vertical, 4)
                    .background(.orange.opacity(0.15), in: Capsule())
            }

            setProgressHeader

            Spacer()

            VStack(spacing: 16) {
                Text("\(viewModel.currentTargetReps)")
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                Text(viewModel.isTimedExercise ? "seconds" : "target reps")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if viewModel.countingMode == .realTime {
                Button("Start Set \(viewModel.currentSetIndex + 1)") {
                    viewModel.startRealTimeSet()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else if viewModel.isTimedExercise {
                Button("Start Hold \(viewModel.currentSetIndex + 1)") {
                    setStartOrientation = UIDevice.current.orientation.stringValue
                    viewModel.startTimedSet()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button("Start Set \(viewModel.currentSetIndex + 1)") {
                    showNudge = false
                    viewModel.startSet()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding()
    }

    private var inSetView: some View {
        VStack(spacing: 32) {
            setProgressHeader

            Spacer()

            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Text("\(viewModel.currentTargetReps)")
                        .font(.system(size: 80, weight: .bold, design: .rounded))
                    Text("target reps")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ElapsedTimerView()
            }

            Spacer()

            Button("Done with Set") {
                viewModel.endSet()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }

    private var realTimeSetView: some View {
        VStack(spacing: 32) {
            setProgressHeader

            Spacer()

            VStack(spacing: 16) {
                Text("\(viewModel.currentTargetReps)")
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                Text("target reps")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            RealTimeCountingView(
                targetReps: viewModel.currentTargetReps,
                repCounter: repCounter
            ) { actual in
                let url = sensorConsented ? motionRecording.stopRecording() : nil
                if dualRecordingEnabled {
                    let exerciseId = viewModel.enrolment?.exerciseDefinition?.exerciseId ?? ""
                    watchConnectivity.sendRecordingStop(
                        exerciseId: exerciseId,
                        setNumber: viewModel.currentSetIndex + 1
                    )
                }
                let duration = realTimeSetStartDate.map { Date.now.timeIntervalSince($0) } ?? 0
                realTimeSetStartDate = nil
                viewModel.completeRealTimeSet(actual: actual, context: modelContext, recordingURL: url, duration: duration)
            }
            .id(viewModel.currentSetIndex)
        }
        .padding()
    }

    private var setProgressHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                if let variation = viewModel.variationName {
                    Text(variation)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)
                }
                Text("Set \(viewModel.currentSetIndex + 1) of \(viewModel.totalSets)  ·  Day \(viewModel.enrolment?.currentDay ?? 0)  ·  Level \(viewModel.enrolment?.currentLevel ?? 0)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ExerciseInfoButton(
                    exerciseId: exerciseId,
                    exerciseName: viewModel.exerciseName,
                    level: viewModel.enrolment?.currentLevel ?? 1
                )
            }
            Spacer()
            if let next = viewModel.prescription?.sets[safe: viewModel.currentSetIndex + 1] {
                Text("Next: \(next)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func dismissNudge() {
        showNudge = false
        markExerciseSeen()
    }

    private func markExerciseSeen() {
        guard let s = settings,
              !s.seenExerciseInfo.contains(exerciseId) else { return }
        s.seenExerciseInfo.append(exerciseId)
        try? modelContext.save()
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension UIDeviceOrientation {
    var stringValue: String {
        switch self {
        case .portrait: "portrait"
        case .portraitUpsideDown: "portraitUpsideDown"
        case .landscapeLeft: "landscapeLeft"
        case .landscapeRight: "landscapeRight"
        case .faceUp: "faceUp"
        case .faceDown: "faceDown"
        default: "unknown"
        }
    }
}
