# Technical Architecture

> Last updated: 2026-04-03

---

## Key Decisions

- Swift 6.2 with main-actor default isolation for both app targets
- `@Observable` view models, all implicitly `@MainActor`
- No GCD, no Combine — Swift concurrency only
- `NavigationStack` with `navigationDestination(for:)` on iOS
- Core Motion uses `OperationQueue` callbacks (framework interop — one of the few non-async patterns)
- Each type in its own file; subviews extracted as separate `View` structs
- Deployment targets: iOS 18.0, watchOS 10.6

---

## Project Structure

```
inch-project/
├── inch/                                  # Xcode project
│   ├── inch/                              # iOS app target
│   │   ├── inchApp.swift                  # @main, ModelContainer, environment setup
│   │   ├── Resources/
│   │   │   └── exercise-data.json         # Bundled exercise progressions
│   │   ├── Features/
│   │   │   ├── Onboarding/
│   │   │   │   ├── OnboardingCoordinatorView.swift
│   │   │   │   ├── EnrolmentView.swift
│   │   │   │   ├── EnrolmentViewModel.swift
│   │   │   │   ├── ExerciseSelectionCard.swift
│   │   │   │   ├── PlacementTestView.swift
│   │   │   │   ├── PlacementExerciseCard.swift
│   │   │   │   ├── DataConsentView.swift
│   │   │   │   └── DemographicTagsView.swift
│   │   │   ├── Today/
│   │   │   │   ├── TodayView.swift
│   │   │   │   ├── TodayViewModel.swift
│   │   │   │   ├── ExerciseCard.swift
│   │   │   │   ├── TodaySessionBanner.swift
│   │   │   │   ├── RestDayView.swift
│   │   │   │   ├── UpcomingSessionCard.swift
│   │   │   │   ├── StreakRecoveryBanner.swift
│   │   │   │   ├── TodayDemographicsNudge.swift
│   │   │   │   └── RecoveryTipView.swift
│   │   │   ├── Workout/
│   │   │   │   ├── WorkoutSessionView.swift
│   │   │   │   ├── WorkoutViewModel.swift
│   │   │   │   ├── RealTimeCountingView.swift
│   │   │   │   ├── PostSetConfirmationView.swift
│   │   │   │   ├── RestTimerView.swift
│   │   │   │   ├── ExerciseCompleteView.swift
│   │   │   │   ├── TestDayView.swift
│   │   │   │   ├── TimedSetView.swift
│   │   │   │   ├── PreSetCountdownView.swift
│   │   │   │   ├── ElapsedTimerView.swift
│   │   │   │   ├── ExerciseInfoButton.swift
│   │   │   │   ├── ExerciseInfoSheet.swift
│   │   │   │   ├── ExerciseNudgeBanner.swift
│   │   │   │   ├── AchievementCelebrationView.swift
│   │   │   │   ├── AchievementBanner.swift
│   │   │   │   ├── AchievementSheet.swift
│   │   │   │   ├── ExerciseContent.swift
│   │   │   │   ├── LoopingVideoView.swift
│   │   │   │   ├── WorkoutSounds.swift
│   │   │   │   └── ConfettiView.swift
│   │   │   ├── Program/
│   │   │   │   ├── ProgramView.swift
│   │   │   │   ├── ProgramViewModel.swift
│   │   │   │   ├── ExerciseDetailView.swift
│   │   │   │   ├── ExerciseDetailViewModel.swift
│   │   │   │   ├── SessionHistoryChart.swift
│   │   │   │   ├── SessionSummary.swift
│   │   │   │   └── UpcomingScheduleList.swift
│   │   │   ├── History/
│   │   │   │   ├── HistoryView.swift
│   │   │   │   ├── HistoryViewModel.swift
│   │   │   │   ├── HistoryLogView.swift
│   │   │   │   ├── HistoryStatsView.swift
│   │   │   │   ├── SessionDetailView.swift
│   │   │   │   ├── DayGroupRow.swift
│   │   │   │   ├── ExerciseSummaryRow.swift
│   │   │   │   ├── WeeklyVolumeChart.swift
│   │   │   │   └── TrophyShelfView.swift
│   │   │   ├── Settings/
│   │   │   │   ├── SettingsView.swift
│   │   │   │   ├── SettingsViewModel.swift
│   │   │   │   ├── RestTimerSettingsView.swift
│   │   │   │   ├── NotificationsSettingsView.swift
│   │   │   │   ├── PrivacySettingsView.swift
│   │   │   │   ├── ManageEnrolmentsView.swift
│   │   │   │   ├── ScheduleSettingsView.swift
│   │   │   │   ├── TimedExerciseSettingsView.swift
│   │   │   │   ├── TrackingMethodView.swift
│   │   │   │   ├── AboutMeView.swift
│   │   │   │   └── DemographicPickerSheet.swift
│   │   │   └── Debug/                     # Internal debug panel (debug builds only)
│   │   │       ├── DebugPanelSection.swift
│   │   │       ├── DebugViewModel.swift
│   │   │       └── DebugCheckKey.swift
│   │   ├── Navigation/
│   │   │   ├── AppTabView.swift
│   │   │   ├── NavigationDestinations.swift
│   │   │   └── RootView.swift
│   │   └── Services/
│   │       ├── AnalyticsService.swift
│   │       ├── DataUploadService.swift
│   │       ├── HealthKitService.swift
│   │       ├── MotionRecordingService.swift
│   │       ├── NotificationService.swift
│   │       ├── ForegroundNotificationDelegate.swift
│   │       ├── WatchConnectivityService.swift
│   │       ├── WatchSensorMetadata.swift
│   │       └── MetricKitService.swift
│   └── inchwatch Watch App/               # watchOS app target
│       ├── Features/
│       │   ├── WatchTodayView.swift
│       │   ├── WatchRestDayView.swift
│       │   ├── WatchWorkoutView.swift
│       │   ├── WatchWorkoutViewModel.swift
│       │   ├── WatchReadyView.swift
│       │   ├── WatchInSetView.swift
│       │   ├── WatchRealTimeCountingView.swift
│       │   ├── WatchPostSetView.swift
│       │   ├── WatchTimedSetView.swift
│       │   ├── WatchRestTimerView.swift
│       │   ├── WatchExerciseCompleteView.swift
│       │   ├── WatchHistoryView.swift
│       │   ├── WatchHistoryDetailView.swift
│       │   ├── WatchHistoryRow.swift
│       │   ├── WatchHRBadge.swift
│       │   └── WatchSettingsView.swift
│       ├── Models/
│       │   ├── WatchHistoryStore.swift
│       │   ├── WatchHistoryEntry.swift
│       │   ├── WatchRecordingTrigger.swift
│       │   └── WatchSettings.swift
│       └── Services/
│           ├── WatchConnectivityService.swift
│           ├── WatchMotionRecordingService.swift
│           └── WatchHealthService.swift
├── Shared/                                # Swift package shared by both targets
│   ├── Package.swift
│   ├── Sources/InchShared/
│   │   ├── Models/                        # SwiftData @Model classes
│   │   │   ├── ExerciseDefinition.swift
│   │   │   ├── LevelDefinition.swift
│   │   │   ├── DayPrescription.swift
│   │   │   ├── ExerciseEnrolment.swift
│   │   │   ├── CompletedSet.swift
│   │   │   ├── SensorRecording.swift
│   │   │   ├── UserSettings.swift
│   │   │   ├── StreakState.swift
│   │   │   ├── Achievement.swift
│   │   │   ├── UserEntitlement.swift
│   │   │   ├── DifficultyRating.swift
│   │   │   ├── Enums.swift
│   │   │   └── BodyweightSchema.swift     # Versioned schema + migration plan
│   │   ├── Engine/                        # Pure business logic (no SwiftData dependency)
│   │   │   ├── SchedulingEngine.swift
│   │   │   ├── ConflictDetector.swift
│   │   │   ├── ConflictResolver.swift
│   │   │   ├── StreakCalculator.swift
│   │   │   ├── ExerciseDataLoader.swift
│   │   │   ├── AdaptationEngine.swift
│   │   │   ├── DailyLoadAdvisor.swift
│   │   │   ├── DailyLoadContext.swift
│   │   │   ├── LoadAdvisory.swift
│   │   │   ├── LoadAdvisoryCopy.swift
│   │   │   ├── AchievementChecker.swift
│   │   │   ├── RepCounter.swift
│   │   │   ├── EnrolmentSnapshot.swift
│   │   │   ├── DaySnapshot.swift
│   │   │   ├── ProjectedDay.swift
│   │   │   ├── ProjectedSession.swift
│   │   │   ├── CompletedExerciseRecord.swift
│   │   │   └── PendingExerciseRecord.swift
│   │   └── Transfer/                      # WatchConnectivity DTOs
│   │       ├── WatchSession.swift
│   │       ├── WatchCompletionReport.swift
│   │       └── WatchSetResult.swift
│   └── Tests/InchSharedTests/
│       ├── Engine/
│       │   ├── SchedulingEngineTests.swift
│       │   ├── ConflictDetectorTests.swift
│       │   ├── ConflictResolverTests.swift
│       │   ├── StreakCalculatorTests.swift
│       │   ├── LoadAdvisoryCopyTests.swift
│       │   └── ExerciseDataLoaderTests.swift
│       └── ...
└── files/                                 # Spec and planning documents
    ├── bodyweight-ux-design-v2.md
    ├── exercise-data.json
    ├── data-model.md
    ├── scheduling-engine.md
    ├── architecture.md                    # This file
    ├── framework-guidance.md
    ├── backend-api.md
    └── v1-1-features.md
```

---

## Target Configuration

| Setting | iOS App | watchOS App | Shared Package |
|---|---|---|---|
| Deployment target | iOS 18.0 | watchOS 10.6 | iOS 18.0 / watchOS 10.6 |
| Swift version | 6.2 | 6.2 | 6.2 |
| Default actor isolation | MainActor | MainActor | **None** (library) |
| Strict concurrency | Complete | Complete | Complete |

The Shared package does NOT use main-actor default isolation — it is a library and its types must be usable from any isolation context. Both app targets do use it, so most view and service code is implicitly `@MainActor`.

---

## State Management

### View Models

All view models are `@Observable` classes. With main-actor default isolation enabled on the app targets, they are implicitly `@MainActor` — no explicit annotation needed.

```swift
@Observable
final class TodayViewModel {
    var dueExercises: [ExerciseEnrolment] = []
    var completedTodayIds: Set<String> = []
    var inProgressTodayIds: Set<String> = []
    var isRestDay: Bool = false
    var conflictWarnings: [String: String] = [:]

    func loadToday(context: ModelContext, showWarnings: Bool = true) {
        let today = Calendar.current.startOfDay(for: .now)
        let descriptor = FetchDescriptor<ExerciseEnrolment>(
            predicate: #Predicate { $0.isActive }
        )
        let all = (try? context.fetch(descriptor)) ?? []
        // ... filter, compute, assign
    }
}
```

### Ownership

- View models owned by their views via `@State`
- `ModelContext` injected via `@Environment(\.modelContext)` and passed into view model methods
- View models do not hold a reference to `ModelContext` — they receive it as a parameter on each call

```swift
struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = TodayViewModel()

    var body: some View {
        // ...
        .onAppear {
            viewModel.loadToday(context: modelContext)
        }
    }
}
```

---

## Navigation Architecture (iOS)

Tab-based with `NavigationStack` per tab. Path-based navigation using `navigationDestination(for:)`.

```swift
enum AppTab: Int, CaseIterable {
    case today, program, history, settings
}

struct AppTabView: View {
    @State private var selectedTab: AppTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Today", systemImage: "calendar", value: AppTab.today) {
                NavigationStack { TodayView() }
            }
            Tab("Program", systemImage: "chart.bar", value: AppTab.program) {
                NavigationStack { ProgramView() }
            }
            Tab("History", systemImage: "clock", value: AppTab.history) {
                NavigationStack { HistoryView() }
            }
            Tab("Settings", systemImage: "gear", value: AppTab.settings) {
                NavigationStack { SettingsView() }
            }
        }
    }
}
```

Navigation destinations are registered once per type using view extensions:

```swift
enum WorkoutDestination: Hashable {
    case exercise(PersistentIdentifier)
    case testDay(PersistentIdentifier)
}

extension View {
    func withWorkoutDestinations() -> some View {
        navigationDestination(for: WorkoutDestination.self) { destination in
            switch destination {
            case .exercise(let id): WorkoutSessionView(enrolmentId: id)
            case .testDay(let id): TestDayView(enrolmentId: id)
            }
        }
    }
}
```

`PersistentIdentifier` is used in destinations rather than model objects, as model instances cannot cross isolation boundaries.

---

## WatchConnectivity Architecture

### iPhone → Watch

The iPhone pushes today's due exercises and user settings to the Watch using `transferUserInfo`. The Watch stores this locally and does not need a live connection to display the today view.

### Watch → iPhone

After each exercise, the Watch sends a `WatchCompletionReport` via `transferUserInfo`. The iPhone's `WatchConnectivityService` receives it, creates `CompletedSet` records in SwiftData, and advances the scheduling state identical to an iPhone-native workout.

Watch sensor recordings (`.bin` files) are sent via `transferFile` — the iPhone stores and queues them for upload alongside its own recordings.

```swift
// iPhone WatchConnectivityService (simplified)
@Observable
final class WatchConnectivityService: NSObject, WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any]
    ) {
        // Decode WatchCompletionReport and yield to async stream
    }

    nonisolated func session(
        _ session: WCSession,
        didReceive file: WCSessionFile
    ) {
        // Move .bin file to permanent storage, create SensorRecording metadata
    }
}
```

All `WCSessionDelegate` methods are `nonisolated` — they fire on a background thread. State updates are dispatched to `@MainActor` via the async stream or explicit `MainActor.run`.

---

## Core Motion Sensor Recording

Sensor recording starts when the "Start Set" screen appears (before the user taps the button) and stops when the set is confirmed. Files are binary, written directly to `sensor_data/` in the app's Application Support directory.

```swift
@Observable
final class MotionRecordingService {
    private let motionManager = CMMotionManager()
    var isRecording: Bool = false

    func startRecording(exerciseId: String, setNumber: Int, sessionId: String, context: ModelContext) {
        // Creates SensorRecording metadata in SwiftData, starts writing to .bin file
    }

    @discardableResult
    func stopRecording() -> URL? {
        // Stops CMMotionManager, finalises the file, returns the URL
    }
}
```

`onSample` callback is assigned before `startRecording()` — this is required to avoid a data race where the sensor queue starts delivering samples before the callback is set.

---

## HealthKit Integration

A single `HKWorkout` is saved per training session. Authorization is requested before the first workout, not at app launch.

```swift
@Observable
final class HealthKitService {
    func requestAuthorization() async {
        // Request share: .workoutType()
        // Request read: .workoutType(), heartRate, activeEnergyBurned
    }

    func saveWorkout(startDate: Date, endDate: Date, totalEnergyBurned: Double?, metadata: [String: Any]) async {
        // HKWorkout with activityType: .functionalStrengthTraining
    }
}
```

---

## Background Upload Task

Sensor recordings are uploaded to Supabase via `BGProcessingTask`. The task requires network connectivity and external power (WiFi + charging).

```swift
@Observable
final class DataUploadService {
    static let taskIdentifier = "com.dailyascent.bodyweight.sensor-upload"

    func scheduleBGUpload() {
        let request = BGProcessingTaskRequest(identifier: Self.taskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = true
        try? BGTaskScheduler.shared.submit(request)
    }
}
```

Upload is gated on `UserSettings.motionDataUploadConsented`. Records with `uploadStatus == .pending` are fetched and uploaded in batches. On success, `uploadStatus` is set to `.uploaded`.

---

## Analytics

`AnalyticsService` maintains an in-memory queue of `AnalyticsEvent` values. Events are flushed to Supabase on `BGProcessingTask` runs alongside sensor data. The queue is persisted to disk between runs. Analytics respects `UserSettings.analyticsEnabled`.

---

## Adaptive Difficulty

`AdaptationEngine` evaluates `ExerciseEnrolment.recentCompletionRatios` and `recentDifficultyRatings` after each workout. It can recommend:

- `.noAction` — continue normally
- `.repeatDay` — mark `needsRepeat = true`, user must repeat current day
- `.earlyTestEligible` — user is performing above level, offer early test
- `.prescriptionReduction` — set `sessionPrescriptionOverride` multiplier for next session

`DailyLoadAdvisor` provides a session-level recommendation (light/normal/hard) based on completed exercises, pending exercises, yesterday's load, and upcoming test days.

---

## Achievements

`AchievementChecker` is called after each workout completes. It checks for milestone conditions (first workout, rep totals, level advances, test passes) and inserts `Achievement` records. Uncelebrated achievements are presented via `AchievementCelebrationView` on the Today screen after the workout.
