# Watch App Enhancements Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add live heart rate display during workouts, a History tab showing past workouts, and a Settings tab with watch-only preferences to the inchwatch watchOS app.

**Architecture:** Three new model/service files (WatchSettings, WatchHistoryEntry, WatchHistoryStore, WatchHealthService), two new UI tabs (History, Settings), and modifications to existing workout views to show HR and respect settings. The app shell switches to a TabView with three tabs using `.tabItem {}` (watchOS 10.6 compatible). HealthKit authorization is lazy (requested on first workout start). The project uses Xcode 16's folder-based sync (`PBXFileSystemSynchronizedRootGroup`) — any `.swift` file created inside the target folder on disk is automatically compiled. No manual "Add Files" steps needed.

**Tech Stack:** SwiftUI, HealthKit (HKWorkoutSession + HKLiveWorkoutBuilder), WatchKit (haptics), UserDefaults (persistence), Swift 6.2 strict concurrency, watchOS 10.6+

> **Tab syntax note:** The design spec states `Tab {}` (watchOS 11+), but `project.pbxproj` confirms `WATCHOS_DEPLOYMENT_TARGET = 10.6` for all watch configurations. This plan intentionally uses `.tabItem {}` (watchOS 10+) to match the actual build target. This overrides the spec's deployment target note, which was incorrect.

---

## Chunk 1: Data Models + Services

### Task 1: WatchSettings

**Files:**
- Create: `inch/inchwatch Watch App/Models/WatchSettings.swift`

- [ ] **Step 1: Create the Models folder and WatchSettings.swift**

```swift
// inch/inchwatch Watch App/Models/WatchSettings.swift
import Foundation

@Observable @MainActor final class WatchSettings {
    var showHeartRate: Bool = true {
        didSet { UserDefaults.standard.set(showHeartRate, forKey: "watch.showHeartRate") }
    }
    var heartRateAlertBPM: Int = 0 {
        didSet { UserDefaults.standard.set(heartRateAlertBPM, forKey: "watch.heartRateAlertBPM") }
    }
    var autoAdvanceAfterRest: Bool = false {
        didSet { UserDefaults.standard.set(autoAdvanceAfterRest, forKey: "watch.autoAdvanceAfterRest") }
    }
    var hapticFinalCountdown: Bool = true {
        didSet { UserDefaults.standard.set(hapticFinalCountdown, forKey: "watch.hapticFinalCountdown") }
    }

    init() {
        let ud = UserDefaults.standard
        if let v = ud.object(forKey: "watch.showHeartRate") as? Bool { showHeartRate = v }
        if let v = ud.object(forKey: "watch.heartRateAlertBPM") as? Int { heartRateAlertBPM = v }
        if let v = ud.object(forKey: "watch.autoAdvanceAfterRest") as? Bool { autoAdvanceAfterRest = v }
        if let v = ud.object(forKey: "watch.hapticFinalCountdown") as? Bool { hapticFinalCountdown = v }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

```bash
xcodebuild build \
  -project inch/inch.xcodeproj \
  -scheme "inchwatch Watch App" \
  -destination "generic/platform=watchOS" \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add "inch/inchwatch Watch App/Models/WatchSettings.swift"
git commit -m "feat(watch): add WatchSettings model with UserDefaults persistence"
```

---

### Task 2: WatchHistoryEntry + WatchHistoryStore

**Files:**
- Create: `inch/inchwatch Watch App/Models/WatchHistoryEntry.swift`
- Create: `inch/inchwatch Watch App/Models/WatchHistoryStore.swift`

- [ ] **Step 1: Create WatchHistoryEntry.swift**

```swift
// inch/inchwatch Watch App/Models/WatchHistoryEntry.swift
import Foundation

struct WatchHistoryEntry: Codable, Identifiable {
    let id: UUID
    let exerciseName: String
    let level: Int
    let dayNumber: Int
    let totalReps: Int
    let setCount: Int
    let completedAt: Date

    init(exerciseName: String, level: Int, dayNumber: Int, totalReps: Int, setCount: Int, completedAt: Date) {
        self.id = UUID()
        self.exerciseName = exerciseName
        self.level = level
        self.dayNumber = dayNumber
        self.totalReps = totalReps
        self.setCount = setCount
        self.completedAt = completedAt
    }
}
```

- [ ] **Step 2: Create WatchHistoryStore.swift**

```swift
// inch/inchwatch Watch App/Models/WatchHistoryStore.swift
import Foundation
import InchShared

@Observable @MainActor final class WatchHistoryStore {
    private let key = "watch.historyEntries"
    private let limit = 30  // oldest entries dropped beyond this cap

    private(set) var entries: [WatchHistoryEntry] = []

    init() {
        load()
    }

    func record(_ report: WatchCompletionReport, exerciseName: String) {
        let totalReps = report.completedSets.reduce(0) { $0 + $1.actualReps }
        let entry = WatchHistoryEntry(
            exerciseName: exerciseName,
            level: report.level,
            dayNumber: report.dayNumber,
            totalReps: totalReps,
            setCount: report.completedSets.count,
            completedAt: report.completedAt
        )
        entries.insert(entry, at: 0)
        if entries.count > limit {
            entries = Array(entries.prefix(limit))
        }
        save()
    }

    // MARK: - Private

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([WatchHistoryEntry].self, from: data)
        else { return }  // decode failure silently returns []
        entries = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
```

- [ ] **Step 3: Build to verify**

```bash
xcodebuild build \
  -project inch/inch.xcodeproj \
  -scheme "inchwatch Watch App" \
  -destination "generic/platform=watchOS" \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add "inch/inchwatch Watch App/Models/WatchHistoryEntry.swift" \
        "inch/inchwatch Watch App/Models/WatchHistoryStore.swift"
git commit -m "feat(watch): add WatchHistoryEntry and WatchHistoryStore"
```

---

### Task 3: WatchHealthService

**Files:**
- Create: `inch/inchwatch Watch App/Services/WatchHealthService.swift`

- [ ] **Step 1: Create WatchHealthService.swift**

```swift
// inch/inchwatch Watch App/Services/WatchHealthService.swift
import Foundation
import HealthKit

@Observable @MainActor final class WatchHealthService: NSObject {
    private(set) var currentBPM: Int? = nil
    private(set) var isAuthorized: Bool = false

    private var healthStore: HKHealthStore?
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    override init() {
        super.init()
        if HKHealthStore.isHealthDataAvailable() {
            healthStore = HKHealthStore()
        }
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        guard let healthStore else { return }
        let read: Set<HKObjectType> = [HKQuantityType(.heartRate)]
        let write: Set<HKSampleType> = [HKObjectType.workoutType()]
        do {
            try await healthStore.requestAuthorization(toShare: write, read: read)
            isAuthorized = true
        } catch {
            isAuthorized = false
        }
    }

    // MARK: - Workout Session

    func startWorkout() async {
        if !isAuthorized { await requestAuthorization() }
        guard isAuthorized, let healthStore else { return }

        let config = HKWorkoutConfiguration()
        config.activityType = .functionalStrengthTraining
        config.locationType = .indoor

        do {
            let newSession = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            let newBuilder = newSession.associatedWorkoutBuilder()
            newBuilder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)
            newBuilder.delegate = self

            self.session = newSession
            self.builder = newBuilder

            newSession.startActivity(with: .now)
            try await newBuilder.beginCollection(at: .now)
        } catch {
            // HealthKit unavailable or denied — HR display stays hidden
        }
    }

    func endWorkout() async {
        guard let session, let builder else { return }
        session.end()
        do {
            try await builder.endCollection(at: .now)
            try await builder.finishWorkout()
        } catch {
            // Best-effort — dismiss proceeds regardless
        }
        self.session = nil
        self.builder = nil
        self.currentBPM = nil
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WatchHealthService: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        guard collectedTypes.contains(HKQuantityType(.heartRate)),
              let stats = workoutBuilder.statistics(for: HKQuantityType(.heartRate)),
              let bpm = stats.mostRecentQuantity()?.doubleValue(for: bpmUnit)
        else { return }
        let rounded = Int(bpm.rounded())
        Task { @MainActor in
            self.currentBPM = rounded
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild build \
  -project inch/inch.xcodeproj \
  -scheme "inchwatch Watch App" \
  -destination "generic/platform=watchOS" \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add "inch/inchwatch Watch App/Services/WatchHealthService.swift"
git commit -m "feat(watch): add WatchHealthService with HKWorkoutSession and live HR"
```

---

### Task 4: HealthKit Entitlements + Build Settings

**Files:**
- Create: `inch/inchwatch Watch App/inchwatch.entitlements`
- Modify: `inch/inch.xcodeproj/project.pbxproj` (via Xcode Signing & Capabilities)

- [ ] **Step 1: Create the entitlements file on disk**

```xml
<!-- inch/inchwatch Watch App/inchwatch.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.healthkit</key>
    <true/>
    <key>com.apple.developer.healthkit.access</key>
    <array/>
    <!-- empty array = no clinical records access, workout-only -->
</dict>
</plist>
```

- [ ] **Step 2: Enable HealthKit capability in Xcode**

In Xcode: select the `inchwatch Watch App` target → Signing & Capabilities → `+` Capability → **HealthKit**. Xcode will write `CODE_SIGN_ENTITLEMENTS` into `project.pbxproj` automatically and update provisioning. It will point to a new entitlements file — delete Xcode's generated one and verify the build setting points to `inchwatch Watch App/inchwatch.entitlements` (the one created in Step 1).

- [ ] **Step 3: Add HealthKit usage description strings to pbxproj**

In the watch target's Debug build configuration in `project.pbxproj` (around line 618), add after `GENERATE_INFOPLIST_FILE = YES;`:

```
INFOPLIST_KEY_NSHealthShareUsageDescription = "Inch logs workouts to Apple Health to show your training history.";
INFOPLIST_KEY_NSHealthUpdateUsageDescription = "Inch logs workouts to Apple Health to show your training history.";
```

Repeat the same two lines in the Release build configuration block (around line 654). These strings match the iOS target.

- [ ] **Step 4: Build to verify**

```bash
xcodebuild build \
  -project inch/inch.xcodeproj \
  -scheme "inchwatch Watch App" \
  -destination "generic/platform=watchOS" \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: Commit**

```bash
git add "inch/inchwatch Watch App/inchwatch.entitlements" \
        inch/inch.xcodeproj/project.pbxproj
git commit -m "feat(watch): add HealthKit entitlement and usage description strings"
```

---

## Chunk 2: App Shell + Infrastructure

### Task 5: App Shell — TabView + Environment Injection

**Files:**
- Modify: `inch/inchwatch Watch App/inchwatchApp.swift`

- [ ] **Step 1: Create placeholder stubs for WatchHistoryView and WatchSettingsView**

These stubs allow the app shell to compile before Tasks 10 and 11 are complete. They will be replaced with full implementations later.

```swift
// inch/inchwatch Watch App/Features/WatchHistoryView.swift
import SwiftUI

struct WatchHistoryView: View {
    var body: some View { Text("History") }
}
```

```swift
// inch/inchwatch Watch App/Features/WatchSettingsView.swift
import SwiftUI

struct WatchSettingsView: View {
    var body: some View { Text("Settings") }
}
```

- [ ] **Step 2: Rewrite inchwatchApp.swift**

```swift
// inch/inchwatch Watch App/inchwatchApp.swift
import SwiftUI
import InchShared

@main
struct inchwatch_Watch_AppApp: App {
    let watchConnectivity = WatchConnectivityService()
    let motionRecording = WatchMotionRecordingService()
    let healthService = WatchHealthService()
    let historyStore = WatchHistoryStore()
    let settings = WatchSettings()

    var body: some Scene {
        WindowGroup {
            TabView {
                WatchTodayView()
                    .tabItem { Label("Today", systemImage: "figure.strengthtraining.traditional") }

                WatchHistoryView()
                    .tabItem { Label("History", systemImage: "clock") }

                WatchSettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape") }
            }
            .environment(watchConnectivity)
            .environment(motionRecording)
            .environment(healthService)
            .environment(historyStore)
            .environment(settings)
            .task {
                watchConnectivity.activate()
                await watchConnectivity.processSessions()
            }
        }
    }
}
```

- [ ] **Step 3: Build to verify**

```bash
xcodebuild build \
  -project inch/inch.xcodeproj \
  -scheme "inchwatch Watch App" \
  -destination "generic/platform=watchOS" \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add "inch/inchwatch Watch App/inchwatchApp.swift" \
        "inch/inchwatch Watch App/Features/WatchHistoryView.swift" \
        "inch/inchwatch Watch App/Features/WatchSettingsView.swift"
git commit -m "feat(watch): add three-tab shell with environment injection and placeholder views"
```

---

### Task 6: WatchTodayView — Replace Paging TabView with List

**Files:**
- Modify: `inch/inchwatch Watch App/Features/WatchTodayView.swift`

- [ ] **Step 1: Rewrite WatchTodayView.swift**

```swift
// inch/inchwatch Watch App/Features/WatchTodayView.swift
import SwiftUI
import InchShared

struct WatchTodayView: View {
    @Environment(WatchConnectivityService.self) private var watchConnectivity
    // Note: settings is NOT read here — WatchWorkoutView.init gains settings: in Task 8.
    // At Task 6 time, WatchWorkoutView still uses init(session:) — updated in Task 8.

    @State private var activeSession: WatchSession?

    var body: some View {
        if watchConnectivity.sessions.isEmpty {
            restDayView
        } else {
            List(watchConnectivity.sessions) { session in
                Button {
                    activeSession = session
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.exerciseName)
                            .font(.headline)
                        Text("Level \(session.level) · Day \(session.dayNumber)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if session.isTest {
                            Text("TEST DAY")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .sheet(item: $activeSession) { session in
                WatchWorkoutView(session: session)  // updated to session:settings: in Task 8
            }
        }
    }

    private var restDayView: some View {
        VStack(spacing: 8) {
            Image(systemName: "moon.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Rest Day")
                .font(.headline)
            if let syncDate = watchConnectivity.lastSyncDate {
                Text("Synced \(syncDate.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild build \
  -project inch/inch.xcodeproj \
  -scheme "inchwatch Watch App" \
  -destination "generic/platform=watchOS" \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add "inch/inchwatch Watch App/Features/WatchTodayView.swift"
git commit -m "feat(watch): replace paging TabView with List in WatchTodayView"
```

---

## Chunk 3: Workout Enhancements

### Task 7: WatchWorkoutViewModel — Settings Injection + Auto-Advance

**Files:**
- Modify: `inch/inchwatch Watch App/Features/WatchWorkoutViewModel.swift`

- [ ] **Step 1: Rewrite WatchWorkoutViewModel.swift**

```swift
// inch/inchwatch Watch App/Features/WatchWorkoutViewModel.swift
import Foundation
import InchShared

@Observable @MainActor
final class WatchWorkoutViewModel {
    private(set) var session: WatchSession
    private let settings: WatchSettings
    private(set) var completedSets: [WatchSetResult] = []
    private(set) var currentSetIndex: Int = 0
    private(set) var pendingRealTimeCount: Int? = nil
    private(set) var phase: WorkoutPhase = .ready

    enum WorkoutPhase: Equatable {
        case ready
        case inSet(startedAt: Date)
        case confirming(targetReps: Int, duration: Double)
        case resting(seconds: Int)
        case complete
    }

    init(session: WatchSession, settings: WatchSettings) {
        self.session = session
        self.settings = settings
    }

    var currentSet: Int { currentSetIndex + 1 }
    var totalSets: Int { session.sets.count }
    var targetReps: Int { session.sets[safe: currentSetIndex] ?? 0 }
    var isLastSet: Bool { currentSetIndex >= session.sets.count - 1 }
    var totalReps: Int { completedSets.reduce(0) { $0 + $1.actualReps } }

    // Accessors for settings — used by the view without exposing full settings object
    var heartRateAlertBPM: Int { settings.heartRateAlertBPM }
    var showHeartRate: Bool { settings.showHeartRate }

    var completionReport: WatchCompletionReport {
        WatchCompletionReport(
            exerciseId: session.exerciseId,
            level: session.level,
            dayNumber: session.dayNumber,
            completedSets: completedSets,
            completedAt: .now
        )
    }

    func startSet() {
        phase = .inSet(startedAt: .now)
    }

    func endSet() {
        guard case .inSet(let startedAt) = phase else { return }
        let duration = Date.now.timeIntervalSince(startedAt)
        phase = .confirming(targetReps: targetReps, duration: duration)
    }

    func endSetRealTime(count: Int) {
        pendingRealTimeCount = count
        endSet()
    }

    func clearPendingRealTimeCount() {
        pendingRealTimeCount = nil
    }

    func confirmSet(actual: Int) {
        guard case .confirming(_, let duration) = phase else { return }

        completedSets.append(WatchSetResult(
            setNumber: currentSet,
            targetReps: session.sets[safe: currentSetIndex] ?? actual,
            actualReps: actual,
            durationSeconds: duration
        ))

        if isLastSet {
            phase = .complete
        } else {
            currentSetIndex += 1
            phase = .resting(seconds: session.restSeconds)
        }
    }

    func finishRest() {
        if settings.autoAdvanceAfterRest {
            phase = .inSet(startedAt: .now)
        } else {
            phase = .ready
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild build \
  -project inch/inch.xcodeproj \
  -scheme "inchwatch Watch App" \
  -destination "generic/platform=watchOS" \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD"
```
Expected: `BUILD SUCCEEDED` (stub views from Task 5 satisfy all references). No errors in this file.

- [ ] **Step 3: Commit**

```bash
git add "inch/inchwatch Watch App/Features/WatchWorkoutViewModel.swift"
git commit -m "feat(watch): inject WatchSettings into WatchWorkoutViewModel for auto-advance"
```

---

### Task 8: WatchWorkoutView — HR Display, startWorkout, Completion Flow

**Files:**
- Modify: `inch/inchwatch Watch App/Features/WatchWorkoutView.swift`
- Modify: `inch/inchwatch Watch App/Features/WatchTodayView.swift` (update call site to pass `settings:`)

- [ ] **Step 1: Rewrite WatchWorkoutView.swift**

```swift
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
```

- [ ] **Step 2: Update WatchTodayView.swift call site**

Find the line in `WatchTodayView.swift`:
```swift
WatchWorkoutView(session: session)  // updated to session:settings: in Task 8
```
Replace with (reading `settings` from environment in `WatchTodayView`):
```swift
// Add to WatchTodayView properties:
@Environment(WatchSettings.self) private var settings

// Update the sheet call site:
WatchWorkoutView(session: session, settings: settings)
```

The final `WatchTodayView` body should pass `settings:` to `WatchWorkoutView`. The temporary comment added in Task 6 is removed.

- [ ] **Step 3: Build to verify**

```bash
xcodebuild build \
  -project inch/inch.xcodeproj \
  -scheme "inchwatch Watch App" \
  -destination "generic/platform=watchOS" \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD"
```
Expected: `BUILD SUCCEEDED` (stub WatchSettingsView from Task 5 satisfies the reference; no other errors).

- [ ] **Step 4: Commit**

```bash
git add "inch/inchwatch Watch App/Features/WatchWorkoutView.swift" \
        "inch/inchwatch Watch App/Features/WatchTodayView.swift"
git commit -m "feat(watch): add HR display, startWorkout guard, and async completion flow"
```

---

### Task 9: WatchRestTimerView — Haptic Final Countdown

**Files:**
- Modify: `inch/inchwatch Watch App/Features/WatchRestTimerView.swift`

- [ ] **Step 1: Rewrite WatchRestTimerView.swift**

```swift
// inch/inchwatch Watch App/Features/WatchRestTimerView.swift
import SwiftUI
import WatchKit

struct WatchRestTimerView: View {
    let restSeconds: Int
    let onSkip: () -> Void

    @Environment(WatchSettings.self) private var settings

    @State private var remaining: Int
    @State private var tenSecondHapticFired = false

    init(restSeconds: Int, onSkip: @escaping () -> Void) {
        self.restSeconds = restSeconds
        self.onSkip = onSkip
        _remaining = State(initialValue: restSeconds)
    }

    private var progress: Double {
        guard restSeconds > 0 else { return 1 }
        return Double(restSeconds - remaining) / Double(restSeconds)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                Text("\(remaining)")
                    .font(.system(size: 36, weight: .semibold, design: .monospaced))
            }
            .frame(width: 80, height: 80)

            Text("Rest")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Skip") { onSkip() }
                .buttonStyle(.bordered)
                .font(.caption)
        }
        .navigationTitle("Rest")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            while remaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                remaining -= 1
                if remaining == 10 && !tenSecondHapticFired {
                    tenSecondHapticFired = true
                    WKInterfaceDevice.current().play(.notification)
                }
                if settings.hapticFinalCountdown && (remaining == 3 || remaining == 2 || remaining == 1) {
                    WKInterfaceDevice.current().play(.click)
                }
            }
            // Triple haptic at rest end
            WKInterfaceDevice.current().play(.success)
            try? await Task.sleep(for: .milliseconds(200))
            WKInterfaceDevice.current().play(.success)
            try? await Task.sleep(for: .milliseconds(200))
            WKInterfaceDevice.current().play(.success)
            onSkip()
        }
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild build \
  -project inch/inch.xcodeproj \
  -scheme "inchwatch Watch App" \
  -destination "generic/platform=watchOS" \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD"
```

- [ ] **Step 3: Commit**

```bash
git add "inch/inchwatch Watch App/Features/WatchRestTimerView.swift"
git commit -m "feat(watch): add haptic final countdown to rest timer"
```

---

## Chunk 4: New Tabs

### Task 10: WatchHistoryView + WatchHistoryDetailView

**Files:**
- Modify: `inch/inchwatch Watch App/Features/WatchHistoryView.swift` (replace stub)
- Create: `inch/inchwatch Watch App/Features/WatchHistoryDetailView.swift`

- [ ] **Step 1: Replace WatchHistoryView.swift stub with full implementation**

```swift
// inch/inchwatch Watch App/Features/WatchHistoryView.swift
import SwiftUI

struct WatchHistoryView: View {
    @Environment(WatchHistoryStore.self) private var historyStore
    @State private var selectedEntry: WatchHistoryEntry?

    var body: some View {
        if historyStore.entries.isEmpty {
            emptyState
        } else {
            List {
                ForEach(groupedEntries, id: \.0) { sectionTitle, entries in
                    Section(sectionTitle) {
                        ForEach(entries) { entry in
                            Button {
                                selectedEntry = entry
                            } label: {
                                historyRow(entry)
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .sheet(item: $selectedEntry) { entry in
                WatchHistoryDetailView(entry: entry)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No workouts yet")
                .font(.headline)
            Text("Complete one from the Today tab.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func historyRow(_ entry: WatchHistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.exerciseName)
                .font(.headline)
            Text("\(entry.totalReps) reps · \(entry.setCount) sets")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(entry.completedAt.formatted(.relative(presentation: .named)))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var groupedEntries: [(String, [WatchHistoryEntry])] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return [] }

        var groups: [(String, [WatchHistoryEntry])] = []
        var remaining = historyStore.entries

        let todayEntries = remaining.filter { calendar.startOfDay(for: $0.completedAt) == today }
        remaining.removeAll { calendar.startOfDay(for: $0.completedAt) == today }
        if !todayEntries.isEmpty { groups.append(("Today", todayEntries)) }

        let yesterdayEntries = remaining.filter { calendar.startOfDay(for: $0.completedAt) == yesterday }
        remaining.removeAll { calendar.startOfDay(for: $0.completedAt) == yesterday }
        if !yesterdayEntries.isEmpty { groups.append(("Yesterday", yesterdayEntries)) }

        var byDay: [Date: [WatchHistoryEntry]] = [:]
        for entry in remaining {
            let day = calendar.startOfDay(for: entry.completedAt)
            byDay[day, default: []].append(entry)
        }
        for day in byDay.keys.sorted(by: >) {
            let title = day.formatted(.dateTime.month(.abbreviated).day())
            if let dayEntries = byDay[day] {
                groups.append((title, dayEntries))
            }
        }

        return groups
    }
}
```

- [ ] **Step 2: Create WatchHistoryDetailView.swift**

```swift
// inch/inchwatch Watch App/Features/WatchHistoryDetailView.swift
import SwiftUI

struct WatchHistoryDetailView: View {
    let entry: WatchHistoryEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.exerciseName)
                    .font(.headline)
                Text("Level \(entry.level) · Day \(entry.dayNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Divider()
                HStack {
                    Text("Total reps").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(entry.totalReps)").font(.caption).fontWeight(.semibold)
                }
                HStack {
                    Text("Sets").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(entry.setCount)").font(.caption).fontWeight(.semibold)
                }
                Divider()
                Text(entry.completedAt.formatted(.dateTime.month().day().hour().minute()))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding()
        }
    }
}
```

- [ ] **Step 3: Build to verify**

```bash
xcodebuild build \
  -project inch/inch.xcodeproj \
  -scheme "inchwatch Watch App" \
  -destination "generic/platform=watchOS" \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD"
```
Expected: `BUILD SUCCEEDED` (stub WatchSettingsView from Task 5 satisfies the reference).

- [ ] **Step 4: Commit**

```bash
git add "inch/inchwatch Watch App/Features/WatchHistoryView.swift" \
        "inch/inchwatch Watch App/Features/WatchHistoryDetailView.swift"
git commit -m "feat(watch): add WatchHistoryView with grouped list and detail sheet"
```

---

### Task 11: WatchSettingsView

**Files:**
- Create: `inch/inchwatch Watch App/Features/WatchSettingsView.swift`

- [ ] **Step 1: Create WatchSettingsView.swift**

Note: The spec lists both workout toggles under a single "Workout" section with per-toggle footers. SwiftUI `Section` supports only one footer, so the two toggles are split into two sections — "Workout" (auto-start, with its footer) and an anonymous second section (countdown haptics, with its footer). This is the standard watchOS pattern for per-toggle footers and is functionally equivalent to the spec intent.

```swift
// inch/inchwatch Watch App/Features/WatchSettingsView.swift
import SwiftUI

struct WatchSettingsView: View {
    @Environment(WatchSettings.self) private var settings
    @Environment(WatchHealthService.self) private var healthService

    var body: some View {
        @Bindable var settings = settings
        List {
            if healthService.isAuthorized {
                Section("Heart Rate") {
                    Toggle("Show heart rate", isOn: $settings.showHeartRate)

                    Picker("High HR alert", selection: $settings.heartRateAlertBPM) {
                        Text("Off").tag(0)
                        Text("150 BPM").tag(150)
                        Text("160 BPM").tag(160)
                        Text("170 BPM").tag(170)
                        Text("180 BPM").tag(180)
                    }
                    .pickerStyle(.navigationLink)
                }
            }

            Section("Workout") {
                Toggle("Auto-start next set", isOn: $settings.autoAdvanceAfterRest)
            } footer: {
                Text("Skips the ready screen and begins the next set automatically after rest ends.")
            }

            // Separate section so "Countdown haptics" gets its own footer text
            Section {
                Toggle("Countdown haptics", isOn: $settings.hapticFinalCountdown)
            } footer: {
                Text("Taps your wrist at 3, 2, and 1 seconds remaining in the rest timer.")
            }
        }
        .navigationTitle("Settings")
    }
}
```

- [ ] **Step 2: Build both targets — expect full BUILD SUCCEEDED**

```bash
xcodebuild build \
  -project inch/inch.xcodeproj \
  -scheme "inchwatch Watch App" \
  -destination "generic/platform=watchOS" \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD"

xcodebuild build \
  -project inch/inch.xcodeproj \
  -scheme inch \
  -destination "generic/platform=iOS" \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD"
```
Expected: Both `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add "inch/inchwatch Watch App/Features/WatchSettingsView.swift"
git commit -m "feat(watch): add WatchSettingsView with HR and workout settings"
```

---

### Task 12: Final Verification

- [ ] **Step 1: Install to Apple Watch and smoke-test**

Build and run the `inchwatch Watch App` scheme on your Apple Watch via Xcode.

1. Three tabs appear at the bottom (Today, History, Settings)
2. Today tab shows exercise list (not paging cards)
3. Start a workout → HR badge appears in corner after ~10 seconds (first HR reading takes time)
4. Complete a workout → History tab shows the entry grouped under "Today"
5. Settings tab → toggles work, HR alert picker drills to selection list
6. Enable "Auto-start next set" → complete a set, rest timer ends, next set begins without tapping "Start"
7. Enable "Countdown haptics" → feel 3 taps at 3/2/1 seconds before rest ends

- [ ] **Step 2: Final commit**

```bash
git add "inch/inchwatch Watch App/inchwatchApp.swift" \
        "inch/inchwatch Watch App/Models/WatchSettings.swift" \
        "inch/inchwatch Watch App/Models/WatchHistoryEntry.swift" \
        "inch/inchwatch Watch App/Models/WatchHistoryStore.swift" \
        "inch/inchwatch Watch App/Services/WatchHealthService.swift" \
        "inch/inchwatch Watch App/Features/WatchTodayView.swift" \
        "inch/inchwatch Watch App/Features/WatchWorkoutView.swift" \
        "inch/inchwatch Watch App/Features/WatchWorkoutViewModel.swift" \
        "inch/inchwatch Watch App/Features/WatchRestTimerView.swift" \
        "inch/inchwatch Watch App/Features/WatchHistoryView.swift" \
        "inch/inchwatch Watch App/Features/WatchHistoryDetailView.swift" \
        "inch/inchwatch Watch App/Features/WatchSettingsView.swift" \
        "inch/inchwatch Watch App/inchwatch.entitlements" \
        inch/inch.xcodeproj/project.pbxproj
git commit -m "feat(watch): complete watch app enhancements — history, settings, live HR"
```
