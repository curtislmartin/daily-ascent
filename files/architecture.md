# Technical Architecture

> **Key decisions informed by agent skills:**
> - Swift 6.2 with main-actor default isolation for both app targets
> - `@Observable` view models, all implicitly `@MainActor`
> - No GCD, no Combine — Swift concurrency only
> - NavigationStack with `navigationDestination(for:)` on iOS
> - AsyncStream for delegate-based APIs (WatchConnectivity, CoreMotion)
> - Each type in its own file, subviews extracted as separate View structs
> - Minimum deployment: iOS 18.0, watchOS 11.0 (for `#Index`, modern SwiftData)

---

## Xcode Project Structure

```
Inch/
├── Inch.xcodeproj
├── CLAUDE.md
├── Shared/                          # Shared Swift package (iOS + watchOS)
│   ├── Package.swift
│   ├── Sources/
│   │   ├── Models/                  # SwiftData @Model classes
│   │   │   ├── ExerciseDefinition.swift
│   │   │   ├── LevelDefinition.swift
│   │   │   ├── DayPrescription.swift
│   │   │   ├── ExerciseEnrolment.swift
│   │   │   ├── CompletedSet.swift
│   │   │   ├── SensorRecording.swift
│   │   │   ├── UserSettings.swift
│   │   │   ├── StreakState.swift
│   │   │   ├── UserEntitlement.swift
│   │   │   └── Enums.swift          # MuscleGroup, CountingMode, etc.
│   │   ├── Engine/                  # Pure business logic
│   │   │   ├── SchedulingEngine.swift
│   │   │   ├── ConflictDetector.swift
│   │   │   ├── ConflictResolver.swift
│   │   │   ├── StreakCalculator.swift
│   │   │   └── ExerciseDataLoader.swift
│   │   ├── Transfer/               # WatchConnectivity DTOs
│   │   │   ├── WatchSession.swift
│   │   │   ├── WatchCompletionReport.swift
│   │   │   └── WatchSetResult.swift
│   │   └── Utilities/
│   │       └── DateHelpers.swift
│   └── Tests/
│       ├── SchedulingEngineTests.swift
│       ├── ConflictDetectorTests.swift
│       ├── ConflictResolverTests.swift
│       ├── StreakCalculatorTests.swift
│       └── ExerciseDataLoaderTests.swift
├── InchApp/                         # iOS app target
│   ├── InchApp.swift                # @main, ModelContainer setup
│   ├── Resources/
│   │   └── exercise-data.json       # Bundled exercise progressions
│   ├── Features/
│   │   ├── Onboarding/
│   │   │   ├── EnrolmentView.swift
│   │   │   ├── ExerciseSelectionCard.swift
│   │   │   ├── PlacementTestView.swift
│   │   │   └── DataConsentView.swift
│   │   ├── Today/
│   │   │   ├── TodayView.swift
│   │   │   ├── ExerciseCard.swift
│   │   │   ├── RestDayView.swift
│   │   │   └── TodayViewModel.swift
│   │   ├── Workout/
│   │   │   ├── WorkoutSessionView.swift
│   │   │   ├── RealTimeCountingView.swift
│   │   │   ├── PostSetConfirmationView.swift
│   │   │   ├── RestTimerView.swift
│   │   │   ├── ExerciseCompleteView.swift
│   │   │   ├── TestDayView.swift
│   │   │   └── WorkoutViewModel.swift
│   │   ├── Program/
│   │   │   ├── ProgramView.swift
│   │   │   ├── ExerciseDetailView.swift
│   │   │   └── ProgramViewModel.swift
│   │   ├── History/
│   │   │   ├── HistoryView.swift
│   │   │   ├── SessionDetailView.swift
│   │   │   └── HistoryViewModel.swift
│   │   └── Settings/
│   │       ├── SettingsView.swift
│   │       ├── RestTimerSettingsView.swift
│   │       ├── PrivacySettingsView.swift
│   │       └── SettingsViewModel.swift
│   ├── Services/
│   │   ├── WatchConnectivityService.swift
│   │   ├── MotionRecordingService.swift
│   │   ├── HealthKitService.swift
│   │   ├── DataUploadService.swift
│   │   └── NotificationService.swift
│   ├── Navigation/
│   │   ├── AppTabView.swift
│   │   ├── NavigationDestinations.swift
│   │   └── AppRouter.swift
│   └── Info.plist
├── InchWatch/                       # watchOS app target
│   ├── InchWatchApp.swift
│   ├── Features/
│   │   ├── WatchTodayView.swift
│   │   ├── WatchWorkoutView.swift
│   │   ├── WatchRealTimeCountingView.swift
│   │   ├── WatchPostSetView.swift
│   │   ├── WatchRestTimerView.swift
│   │   ├── WatchExerciseCompleteView.swift
│   │   └── WatchWorkoutViewModel.swift
│   ├── Services/
│   │   ├── WatchConnectivityService.swift  # Watch-side counterpart
│   │   └── WatchMotionRecordingService.swift
│   └── Info.plist
└── Specs/                           # All planning documents
    ├── bodyweight-ux-design-v2.md
    ├── exercise-data.json
    ├── data-model.md
    ├── scheduling-engine.md
    ├── architecture.md              # This file
    ├── framework-guidance.md
    └── backend-api.md
```

---

## Target Configuration

| Setting | iOS App | watchOS App | Shared Package |
|---|---|---|---|
| Deployment target | iOS 18.0 | watchOS 11.0 | iOS 18.0 / watchOS 11.0 |
| Swift version | 6.2 | 6.2 | 6.2 |
| Default actor isolation | MainActor | MainActor | **None** (library) |
| Strict concurrency | Complete | Complete | Complete |

The Shared package does NOT use main-actor default isolation because it's a library — its types need to be usable from any isolation context. The app targets do use it, which means most view and service code is implicitly `@MainActor`.

---

## State Management

### View Models

All view models are `@Observable` classes. With main-actor default isolation enabled on the app target, they are implicitly `@MainActor` — no explicit annotation needed.

```swift
// TodayViewModel.swift
@Observable
final class TodayViewModel {
    var dueExercises: [ExerciseEnrolment] = []
    var isRestDay: Bool = false
    var conflictWarnings: [String: String] = [:]  // exerciseId -> warning message
    
    private let modelContext: ModelContext
    private let scheduler: SchedulingEngine
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.scheduler = SchedulingEngine()
    }
    
    func loadToday() {
        let today = Calendar.current.startOfDay(for: .now)
        let descriptor = FetchDescriptor<ExerciseEnrolment>(
            predicate: #Predicate { $0.isActive && $0.nextScheduledDate != nil }
        )
        // Filter in-memory for date comparison (SwiftData date predicates are limited)
        let all = (try? modelContext.fetch(descriptor)) ?? []
        dueExercises = all.filter { enrolment in
            guard let scheduled = enrolment.nextScheduledDate else { return false }
            return Calendar.current.startOfDay(for: scheduled) <= today
        }
        isRestDay = dueExercises.isEmpty
    }
}
```

### Ownership

Following SwiftUI Pro guidance:
- View models owned by their views via `@State`
- `ModelContext` injected via `@Environment(\.modelContext)`
- View models that need `ModelContext` receive it in `init` or via a method

```swift
struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: TodayViewModel?
    
    var body: some View {
        // ...
    }
    
    func setupViewModel() {
        if viewModel == nil {
            viewModel = TodayViewModel(modelContext: modelContext)
        }
    }
}
```

---

## Navigation Architecture (iOS)

Tab-based with NavigationStack per tab. Path-based navigation using `navigationDestination(for:)`.

```swift
// AppTabView.swift
enum AppTab: String, CaseIterable {
    case today, program, history
}

struct AppTabView: View {
    @State private var selectedTab: AppTab = .today
    
    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Today", systemImage: "calendar", value: .today) {
                NavigationStack {
                    TodayView()
                }
            }
            Tab("Program", systemImage: "chart.bar", value: .program) {
                NavigationStack {
                    ProgramView()
                }
            }
            Tab("History", systemImage: "clock", value: .history) {
                NavigationStack {
                    HistoryView()
                }
            }
        }
    }
}
```

Navigation destinations registered once per type:

```swift
// NavigationDestinations.swift
enum WorkoutDestination: Hashable {
    case exercise(PersistentIdentifier)  // ExerciseEnrolment ID
    case testDay(PersistentIdentifier)
}

extension View {
    func withWorkoutDestinations() -> some View {
        navigationDestination(for: WorkoutDestination.self) { destination in
            switch destination {
            case .exercise(let id):
                WorkoutSessionView(enrolmentId: id)
            case .testDay(let id):
                TestDayView(enrolmentId: id)
            }
        }
    }
}
```

Note: Navigation destinations use `PersistentIdentifier`, not model objects, because model instances cannot cross isolation boundaries safely.

---

## WatchConnectivity Architecture

### iPhone Side

```swift
// WatchConnectivityService.swift (iOS)
@Observable
final class WatchConnectivityService: NSObject, WCSessionDelegate {
    private var session: WCSession?
    
    // Incoming data from Watch as AsyncStream
    private let _completionReports: AsyncStream<WatchCompletionReport>.Continuation
    let completionReports: AsyncStream<WatchCompletionReport>
    
    override init() {
        let (stream, continuation) = AsyncStream<WatchCompletionReport>.makeStream()
        self.completionReports = stream
        self._completionReports = continuation
        super.init()
    }
    
    func activate() {
        guard WCSession.isSupported() else { return }
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }
    
    // Push schedule to Watch
    func sendSchedule(_ sessions: [WatchSession]) {
        guard let session, session.activationState == .activated else { return }
        do {
            let data = try JSONEncoder().encode(sessions)
            session.transferUserInfo(["type": "schedule", "data": data])
        } catch {
            // handle encoding error
        }
    }
    
    // WCSessionDelegate — receive completion reports
    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any]
    ) {
        guard let type = userInfo["type"] as? String,
              type == "completion",
              let data = userInfo["data"] as? Data,
              let report = try? JSONDecoder().decode(WatchCompletionReport.self, from: data)
        else { return }
        
        _completionReports.yield(report)
    }
    
    // Handle incoming sensor data files
    nonisolated func session(
        _ session: WCSession,
        didReceive file: WCSessionFile
    ) {
        // Move file to permanent storage, create SensorRecording metadata
        // This runs on a background thread — use MainActor.assumeIsolated
        // only if you know you're on main, otherwise dispatch properly
    }
    
    // Required delegate methods
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith state: WCSessionActivationState,
        error: Error?
    ) {}
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()  // reactivate for Watch switching
    }
}
```

### Watch Side

The Watch side mirrors this with its own `WCSessionDelegate`. It receives `WatchSession` arrays and stores them locally. It sends back `WatchCompletionReport` after each exercise and sensor data files via `transferFile`.

---

## Core Motion Sensor Recording

```swift
// MotionRecordingService.swift
@Observable
final class MotionRecordingService {
    private let motionManager = CMMotionManager()
    private var recordingTask: Task<Void, Never>?
    private var fileHandle: FileHandle?
    
    var isRecording: Bool = false
    
    func startRecording(exerciseId: String, setNumber: Int) {
        guard motionManager.isAccelerometerAvailable,
              motionManager.isGyroAvailable else { return }
        
        // Create temp file for this set's data
        let fileName = "\(exerciseId)_set\(setNumber)_\(Date.now.timeIntervalSince1970).bin"
        let filePath = URL.documentsDirectory.appending(path: "sensor_data/\(fileName)")
        
        // Start both sensors at 100Hz
        motionManager.accelerometerUpdateInterval = 1.0 / 100.0
        motionManager.gyroUpdateInterval = 1.0 / 100.0
        
        // Use operation queue for sensor callbacks, write to file
        let queue = OperationQueue()
        queue.name = "motion-recording"
        queue.maxConcurrentOperationCount = 1
        
        motionManager.startAccelerometerUpdates(to: queue) { data, error in
            guard let data else { return }
            // Write binary: timestamp(8) + ax(8) + ay(8) + az(8) = 32 bytes
            // Actual implementation writes to the file handle
        }
        
        motionManager.startGyroUpdates(to: queue) { data, error in
            guard let data else { return }
            // Write binary: timestamp(8) + gx(8) + gy(8) + gz(8) = 32 bytes
        }
        
        isRecording = true
    }
    
    func stopRecording() -> URL? {
        motionManager.stopAccelerometerUpdates()
        motionManager.stopGyroUpdates()
        isRecording = false
        // Return the file URL for the recording
        return nil // placeholder
    }
}
```

Note: Core Motion uses `OperationQueue` callbacks — this is one of the few places where non-async code is appropriate per the concurrency skill guidance (framework interop with performance-critical synchronous I/O).

---

## HealthKit Integration

```swift
// HealthKitService.swift
@Observable
final class HealthKitService {
    private let healthStore = HKHealthStore()
    var isAuthorized: Bool = false
    
    func requestAuthorization() async throws {
        let typesToShare: Set<HKSampleType> = [
            HKObjectType.workoutType()
        ]
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
        isAuthorized = true
    }
    
    func saveWorkout(
        startDate: Date,
        endDate: Date,
        totalEnergyBurned: Double?,
        metadata: [String: Any]
    ) async throws {
        let workout = HKWorkout(
            activityType: .functionalStrengthTraining,
            start: startDate,
            end: endDate,
            duration: endDate.timeIntervalSince(startDate),
            totalEnergyBurned: totalEnergyBurned.map {
                HKQuantity(unit: .kilocalorie(), doubleValue: $0)
            },
            totalDistance: nil,
            metadata: metadata
        )
        try await healthStore.save(workout)
    }
}
```

---

## Background Upload Task

```swift
// DataUploadService.swift
import BackgroundTasks

@Observable
final class DataUploadService {
    static let taskIdentifier = "com.inch.bodyweight.sensor-upload"
    
    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else { return }
            Task {
                await self.handleUpload(task: processingTask)
            }
        }
    }
    
    func scheduleUpload() {
        let request = BGProcessingTaskRequest(identifier: Self.taskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = true  // WiFi + charging
        try? BGTaskScheduler.shared.submit(request)
    }
    
    @concurrent
    private func handleUpload(task: BGProcessingTask) async {
        // Fetch pending sensor recordings
        // Compress and upload to Supabase
        // Mark as uploaded on success
        // Re-schedule for next batch
        
        task.expirationHandler = {
            // Clean up partial upload
        }
        
        // ... upload logic ...
        
        task.setTaskCompleted(success: true)
        scheduleUpload()  // schedule next run
    }
}
```

Note: `@concurrent` on `handleUpload` ensures it runs off the main actor (per Swift 6.2 guidance). The `BGProcessingTask` handler needs to do CPU work (compression) and network I/O, so it should not run on the main actor.

---

## Build Order

1. **Shared package**: Models + Enums → ExerciseDataLoader → SchedulingEngine → ConflictDetector → StreakCalculator. Full test coverage.
2. **iOS App shell**: App entry point, ModelContainer, tab navigation, empty views.
3. **Onboarding flow**: EnrolmentView → DataConsentView. Seeds exercise data, creates enrolments.
4. **Today dashboard**: TodayView + TodayViewModel. Shows due exercises.
5. **Workout session**: Both counting modes, rest timers, exercise completion, test day flow.
6. **Program view**: Progress bars, exercise detail.
7. **Settings**: Rest timer overrides, counting mode, privacy.
8. **WatchConnectivity**: iPhone service, schedule sync, completion report handling.
9. **Watch app**: Today view, workout flow, results sync back.
10. **HealthKit**: Authorization, workout logging.
11. **Sensor recording**: Core Motion service, file management.
12. **Background upload**: BGProcessingTask, Supabase upload.
13. **Streak tracking**: Calculator integration with dashboard.
