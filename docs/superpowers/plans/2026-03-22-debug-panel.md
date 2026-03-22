# Debug Panel Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `#if DEBUG`-only "Developer" section to Settings that lets testers seed data, fire notifications, and put the app into specific states for physical device testing.

**Architecture:** Three new files are added to `inch/inch/Features/Debug/`: an enum for UserDefaults keys (`DebugCheckKey`), an `@Observable` class with all action implementations (`DebugViewModel`), and a `SettingsView` extension that provides the debug UI as a `@ViewBuilder` property (`DebugPanelSection`). Two existing services get minor additions. `SettingsView` is modified to embed the debug sections via `#if DEBUG`. All debug files are deleted after testing is complete.

**Tech Stack:** SwiftUI, SwiftData, UserNotifications, WatchConnectivity, HealthKit. No new dependencies.

---

## File Map

| File | Status | Responsibility |
|---|---|---|
| `inch/inch/Features/Debug/DebugCheckKey.swift` | Create | Enum of all UserDefaults keys for checkmark state |
| `inch/inch/Features/Debug/DebugViewModel.swift` | Create | `@Observable` class — checkmark state + all action implementations |
| `inch/inch/Features/Debug/DebugPanelSection.swift` | Create | `SettingsView` extension — `@ViewBuilder var debugContent` with all Section rows |
| `inch/inch/Features/Settings/SettingsView.swift` | Modify | Add `@Environment` service properties + `#if DEBUG` block in List body + `.alert` modifiers |
| `inch/inch/Services/WatchConnectivityService.swift` | Modify | Add `simulateCompletionReport(_:)` internal method |
| `inch/inch/Services/DataUploadService.swift` | Modify | Widen `uploadPending(context:)` from `private` to `internal` |

---

## Chunk 1: Foundation — Keys, Skeleton, Services, UI

### Task 1: Create `DebugCheckKey.swift`

**Files:**
- Create: `inch/inch/Features/Debug/DebugCheckKey.swift`

- [ ] **Step 1: Create the enum with all 32 keys**

Create `inch/inch/Features/Debug/DebugCheckKey.swift`:

```swift
#if DEBUG
import Foundation

enum DebugCheckKey: String, CaseIterable {
    // Scheduling & State
    case schedDueToday      = "debug.schedDueToday"
    case schedRestDay       = "debug.schedRestDay"
    case schedDueTomorrow   = "debug.schedDueTomorrow"
    case conflictDoubleTest = "debug.conflictDoubleTest"
    case conflictSameGroup  = "debug.conflictSameGroup"
    case schedTestDay       = "debug.schedTestDay"
    case advanceL2          = "debug.advanceL2"
    case advanceL3          = "debug.advanceL3"
    case showDemoNudge      = "debug.showDemoNudge"
    case streak0            = "debug.streak0"
    case streak1            = "debug.streak1"
    case streak7            = "debug.streak7"
    case streak30           = "debug.streak30"
    // Notifications
    case notifDailyReminder      = "debug.notifDailyReminder"
    case notifDailyReminderMulti = "debug.notifDailyReminderMulti"
    case notifTestDay            = "debug.notifTestDay"
    case notifStreakProtect0     = "debug.notifStreakProtect0"
    case notifStreakProtect7     = "debug.notifStreakProtect7"
    case notifLevelUnlock        = "debug.notifLevelUnlock"
    case notifScheduleAdj        = "debug.notifScheduleAdj"
    case notifList               = "debug.notifList"
    // History & Charts
    case histSeed4w    = "debug.histSeed4w"
    case histSeed12w   = "debug.histSeed12w"
    case histSeedGaps  = "debug.histSeedGaps"
    case histTestPass  = "debug.histTestPass"
    case histTestFail  = "debug.histTestFail"
    // Watch & HealthKit
    case watchSimReport    = "debug.watchSimReport"
    case watchPushSchedule = "debug.watchPushSchedule"
    case hkLogWorkout      = "debug.hkLogWorkout"
    // Upload & Sensor Data
    case uploadSeedPending = "debug.uploadSeedPending"
    case uploadTrigger     = "debug.uploadTrigger"
    case uploadStatus      = "debug.uploadStatus"
}
#endif
```

- [ ] **Step 2: Add `Features/Debug/` folder to Xcode target**

In Xcode, right-click `inch/inch/Features/` → New Group → "Debug". Add `DebugCheckKey.swift` to the "inch" target (not inchwatchWidget or inchwatch). Verify it appears under `Features/Debug/` in the project navigator.

- [ ] **Step 3: Commit**

```bash
cd /Users/curtismartin/Work/inch-project
git add inch/inch/Features/Debug/DebugCheckKey.swift
git commit -m "feat(debug): add DebugCheckKey enum with all 32 UserDefaults keys"
```

---

### Task 2: Create `DebugViewModel.swift` (skeleton)

**Files:**
- Create: `inch/inch/Features/Debug/DebugViewModel.swift`

- [ ] **Step 1: Create the skeleton with checkmark and alert state only**

Action implementations are added in Chunks 2–3. This task just establishes the observable class and the state it manages.

Create `inch/inch/Features/Debug/DebugViewModel.swift`:

```swift
#if DEBUG
import Foundation
import SwiftData
import UserNotifications
import InchShared

@Observable
final class DebugViewModel {
    // MARK: - Checkmark State

    private let defaults = UserDefaults.standard

    func isDone(_ key: DebugCheckKey) -> Bool {
        defaults.bool(forKey: key.rawValue)
    }

    func markDone(_ key: DebugCheckKey) {
        defaults.set(true, forKey: key.rawValue)
    }

    func resetAllDone() {
        for key in DebugCheckKey.allCases {
            defaults.removeObject(forKey: key.rawValue)
        }
    }

    // MARK: - Info Alert State (non-destructive feedback)

    var alertTitle: String = ""
    var alertMessage: String = ""
    var showAlert: Bool = false

    // MARK: - Danger Confirmation State

    var dangerTitle: String = ""
    var dangerMessage: String = ""
    var pendingDangerAction: (() -> Void)? = nil
    var showDangerConfirmation: Bool = false

    func confirmDanger(title: String, message: String, action: @escaping () -> Void) {
        dangerTitle = title
        dangerMessage = message
        pendingDangerAction = action
        showDangerConfirmation = true
    }
}
#endif
```

- [ ] **Step 2: Add to Xcode target**

Add `DebugViewModel.swift` to the "inch" iOS target in Xcode.

- [ ] **Step 3: Build to verify it compiles**

```bash
cd /Users/curtismartin/Work/inch-project/inch
xcodebuild build \
  -project inch.xcodeproj \
  -scheme inch \
  -destination 'generic/platform=iOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED` with no errors.

- [ ] **Step 4: Commit**

```bash
cd /Users/curtismartin/Work/inch-project
git add inch/inch/Features/Debug/DebugViewModel.swift
git commit -m "feat(debug): add DebugViewModel skeleton with checkmark and alert state"
```

---

### Task 3: Service changes

**Files:**
- Modify: `inch/inch/Services/WatchConnectivityService.swift`
- Modify: `inch/inch/Services/DataUploadService.swift`

- [ ] **Step 1: Add `simulateCompletionReport` to `WatchConnectivityService`**

Open `inch/inch/Services/WatchConnectivityService.swift`. Add this method after the `sendRecordingStop` method (find it by name), before the `// MARK: - Receiving` marker:

```swift
    // MARK: - Debug

    /// Injects a synthetic completion report into the live stream.
    /// Only called from DebugViewModel in #if DEBUG builds.
    func simulateCompletionReport(_ report: WatchCompletionReport) {
        _completionReports.yield(report)
    }
```

- [ ] **Step 2: Widen `uploadPending` in `DataUploadService`**

Open `inch/inch/Services/DataUploadService.swift`. Find `private func uploadPending(context: ModelContext) async {` and change it to:

```swift
    func uploadPending(context: ModelContext) async {
```

(Remove `private`. The default access level in this context is `internal`, which is what `DebugViewModel` needs.)

> **Note:** `uploadPending` is `async`. When `DebugViewModel.triggerForegroundUpload` calls it (added in Chunk 3, Task 9), the call site must use `Task { await dataUpload.uploadPending(context:) }` — do not call it synchronously.

- [ ] **Step 3: Build to verify**

```bash
cd /Users/curtismartin/Work/inch-project/inch
xcodebuild build \
  -project inch.xcodeproj \
  -scheme inch \
  -destination 'generic/platform=iOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
cd /Users/curtismartin/Work/inch-project
git add inch/inch/Services/WatchConnectivityService.swift \
        inch/inch/Services/DataUploadService.swift
git commit -m "feat(debug): expose simulateCompletionReport + internal uploadPending for debug injection"
```

---

### Task 4: `SettingsView` integration + `DebugPanelSection.swift`

**Files:**
- Create: `inch/inch/Features/Debug/DebugPanelSection.swift`
- Modify: `inch/inch/Features/Settings/SettingsView.swift`

This task wires the debug UI into Settings. Row actions are stubs (`markDone` only) — real implementations come in Chunks 2–3. The full row list is established here so the UI is complete and explorable on device.

- [ ] **Step 1: Modify `SettingsView` to add services + debug state**

Open `inch/inch/Features/Settings/SettingsView.swift`. Replace the full file with:

```swift
import SwiftUI
import SwiftData
import InchShared

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = SettingsViewModel()

    #if DEBUG
    @State var debugViewModel = DebugViewModel()
    @Environment(NotificationService.self) var notificationService
    @Environment(WatchConnectivityService.self) var watchConnectivity
    @Environment(HealthKitService.self) var healthKit
    @Environment(DataUploadService.self) var dataUpload
    #endif

    private var showAboutMeBadge: Bool {
        guard let s = viewModel.settings else { return false }
        return !s.hasDemographics
    }

    var body: some View {
        List {
            profileSection
            programSection
            workoutSection
            if let settings = viewModel.settings {
                generalSection(settings: settings)
            }
            privacySection
            #if DEBUG
            debugContent
            #endif
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.load(context: modelContext) }
        #if DEBUG
        .alert(debugViewModel.alertTitle, isPresented: $debugViewModel.showAlert) {
            Button("OK") {}
        } message: {
            Text(debugViewModel.alertMessage)
        }
        .alert(debugViewModel.dangerTitle, isPresented: $debugViewModel.showDangerConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Confirm", role: .destructive) {
                debugViewModel.pendingDangerAction?()
            }
        } message: {
            Text(debugViewModel.dangerMessage)
        }
        #endif
    }

    private var profileSection: some View {
        Section {
            NavigationLink("About Me") {
                AboutMeView(viewModel: viewModel)
            }
            .badge(showAboutMeBadge ? Text("") : nil)
        }
    }

    private var programSection: some View {
        Section("Program") {
            NavigationLink("Manage Exercises") {
                ManageEnrolmentsView()
            }
        }
    }

    private var workoutSection: some View {
        Section("Workout") {
            NavigationLink("Rest Timers") {
                RestTimerSettingsView(viewModel: viewModel)
            }
            NavigationLink("Counting Method") {
                TrackingMethodView(viewModel: viewModel)
            }
        }
    }

    private func generalSection(settings: UserSettings) -> some View {
        Section("General") {
            NavigationLink("Notifications") {
                NotificationsSettingsView(settings: settings)
            }
            NavigationLink("Schedule") {
                ScheduleSettingsView(settings: settings)
            }
            AppearancePicker(settings: settings)
        }
    }

    private var privacySection: some View {
        Section("Privacy") {
            NavigationLink("Data & Privacy") {
                PrivacySettingsView(viewModel: viewModel)
            }
        }
    }
}

private struct AppearancePicker: View {
    @Bindable var settings: UserSettings
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Picker("Appearance", selection: $settings.appearanceMode) {
            Text("System").tag("system")
            Text("Light").tag("light")
            Text("Dark").tag("dark")
        }
        .onChange(of: settings.appearanceMode) {
            try? modelContext.save()
        }
    }
}
```

- [ ] **Step 2: Create `DebugPanelSection.swift` with all rows (stub actions)**

Create `inch/inch/Features/Debug/DebugPanelSection.swift`:

```swift
#if DEBUG
import SwiftUI
import SwiftData
import InchShared

// MARK: - Debug UI extension on SettingsView

extension SettingsView {

    /// All debug sections, embedded in SettingsView's List via #if DEBUG.
    @ViewBuilder
    var debugContent: some View {
        debugSchedulingSection
        debugNotificationsSection
        debugHistorySection
        debugWatchSection
        debugUploadSection
        debugDangerSection
    }

    // MARK: - Scheduling & State

    var debugSchedulingSection: some View {
        Section("Scheduling & State") {
            debugRow("Set exercises due today",
                     sub: "Schedule all enrolments for today",
                     key: .schedDueToday) {
                debugViewModel.setDueToday(context: modelContext)
            }
            debugRow("Force rest day",
                     sub: "Push all exercises to tomorrow → RestDayView",
                     key: .schedRestDay) {
                debugViewModel.forceRestDay(context: modelContext)
            }
            debugRow("Set exercises due tomorrow",
                     sub: "RestDayView 'next training tomorrow' subtext",
                     key: .schedDueTomorrow) {
                debugViewModel.setDueTomorrow(context: modelContext)
            }
            debugRow("Trigger double-test conflict",
                     sub: "Two exercises on test day → 'Two test days scheduled today'",
                     key: .conflictDoubleTest) {
                debugViewModel.triggerDoubleTestConflict(context: modelContext)
            }
            debugRow("Trigger same-group conflict",
                     sub: "Squats (test) + Glute Bridges → 'Same muscle group as today's test'",
                     key: .conflictSameGroup) {
                debugViewModel.triggerSameGroupConflict(context: modelContext)
            }
            debugRow("Set exercise to test day",
                     sub: "Advance Push-Ups currentDay to its test day",
                     key: .schedTestDay) {
                debugViewModel.setExerciseToTestDay(context: modelContext)
            }
            debugRow("Advance exercise to L2",
                     sub: "Push-Ups → Level 2 Day 1",
                     key: .advanceL2) {
                debugViewModel.advancePushUpsToLevel(2, context: modelContext, key: .advanceL2)
            }
            debugRow("Advance exercise to L3",
                     sub: "Push-Ups → Level 3 Day 1",
                     key: .advanceL3) {
                debugViewModel.advancePushUpsToLevel(3, context: modelContext, key: .advanceL3)
            }
            debugRow("Show demographics nudge",
                     sub: "Clear all demographic fields → nudge reappears on Today",
                     key: .showDemoNudge) {
                debugViewModel.showDemographicsNudge(context: modelContext)
            }
            debugRow("Set streak → 0 days",
                     sub: "No flame badge, no streak card on rest day",
                     key: .streak0) {
                debugViewModel.setStreak(0, key: .streak0, context: modelContext)
            }
            debugRow("Set streak → 1 day",
                     sub: "Edge case: 'Start building your streak' messaging",
                     key: .streak1) {
                debugViewModel.setStreak(1, key: .streak1, context: modelContext)
            }
            debugRow("Set streak → 7 days",
                     sub: "Flame badge, streak card, streak protection messaging",
                     key: .streak7) {
                debugViewModel.setStreak(7, key: .streak7, context: modelContext)
            }
            debugRow("Set streak → 30 days",
                     sub: "Tests large number rendering throughout",
                     key: .streak30) {
                debugViewModel.setStreak(30, key: .streak30, context: modelContext)
            }
        }
    }

    // MARK: - Notifications

    var debugNotificationsSection: some View {
        Section("Notifications") {
            debugRow("Fire daily reminder now",
                     sub: "Title: 'Time to train' · Body: 'Push-Ups'",
                     key: .notifDailyReminder) {
                debugViewModel.fireDailyReminder()
            }
            debugRow("Fire daily reminder (multi) now",
                     sub: "Body: '3 exercises today — Push-Ups, Squats, Sit-Ups'",
                     key: .notifDailyReminderMulti) {
                debugViewModel.fireDailyReminderMulti()
            }
            debugRow("Fire test-day reminder now",
                     sub: "Title: 'Test day' · Body: 'Push-Ups — max reps today'",
                     key: .notifTestDay) {
                debugViewModel.fireTestDayReminder()
            }
            debugRow("Fire streak protection (streak = 0) now",
                     sub: "Title: 'Start building your streak'",
                     key: .notifStreakProtect0) {
                debugViewModel.fireStreakProtection(streak: 0, key: .notifStreakProtect0)
            }
            debugRow("Fire streak protection (streak = 7) now",
                     sub: "Title: 'Don't break your streak'",
                     key: .notifStreakProtect7) {
                debugViewModel.fireStreakProtection(streak: 7, key: .notifStreakProtect7)
            }
            debugRow("Fire level unlock now",
                     sub: "Title: 'Level 2 unlocked!' · Push-Ups starts in 2 days",
                     key: .notifLevelUnlock) {
                debugViewModel.fireLevelUnlock(notificationService: notificationService)
            }
            debugRow("Fire schedule adjustment now",
                     sub: "Title: 'Schedule adjusted' · Push-Ups moved to tomorrow",
                     key: .notifScheduleAdj) {
                debugViewModel.fireScheduleAdjustment(notificationService: notificationService)
            }
            debugRow("List pending notifications",
                     sub: "Shows count + identifiers in an alert",
                     key: .notifList) {
                debugViewModel.listPendingNotifications()
            }
        }
    }

    // MARK: - History & Charts

    var debugHistorySection: some View {
        Section("History & Charts") {
            debugRow("Seed 4 weeks of history",
                     sub: "Push-Ups, Squats, Sit-Ups on alternating schedule",
                     key: .histSeed4w) {
                debugViewModel.seedHistory(weeks: 4, withGaps: false, key: .histSeed4w, context: modelContext)
            }
            debugRow("Seed 12 weeks of history",
                     sub: "Tests chart scrolling and week group headers",
                     key: .histSeed12w) {
                debugViewModel.seedHistory(weeks: 12, withGaps: false, key: .histSeed12w, context: modelContext)
            }
            debugRow("Seed history with missed days",
                     sub: "4 weeks with gaps → 'Pushed to tomorrow' + streak reset",
                     key: .histSeedGaps) {
                debugViewModel.seedHistory(weeks: 4, withGaps: true, key: .histSeedGaps, context: modelContext)
            }
            debugRow("Add test day pass to history",
                     sub: "Push-Ups: 55/50 reps — 🏆 row in history log",
                     key: .histTestPass) {
                debugViewModel.addTestDayResult(passed: true, context: modelContext)
            }
            debugRow("Add test day fail to history",
                     sub: "Push-Ups: 43/50 reps — 'Retry next' row in history log",
                     key: .histTestFail) {
                debugViewModel.addTestDayResult(passed: false, context: modelContext)
            }
        }
    }

    // MARK: - Watch & HealthKit

    var debugWatchSection: some View {
        Section("Watch & HealthKit") {
            debugRow("Simulate watch completion report",
                     sub: "Push-Ups L1 D1 · 3 sets × 10 reps → injects into live stream",
                     key: .watchSimReport) {
                debugViewModel.simulateWatchReport(context: modelContext, watchConnectivity: watchConnectivity)
            }
            debugRow("Push today's schedule to watch",
                     sub: "Calls sendTodaySchedule with live enrolments",
                     key: .watchPushSchedule) {
                debugViewModel.pushScheduleToWatch(context: modelContext, watchConnectivity: watchConnectivity)
            }
            debugRow("Log test HealthKit workout",
                     sub: "10-min functional strength training workout, 1 hour ago",
                     key: .hkLogWorkout) {
                debugViewModel.logTestHealthKitWorkout(healthKit: healthKit)
            }
        }
    }

    // MARK: - Upload & Sensor Data

    var debugUploadSection: some View {
        Section("Upload & Sensor Data") {
            debugRow("Seed fake sensor recordings (pending)",
                     sub: "3 × 1 KB stub files + SensorRecording rows with status .pending",
                     key: .uploadSeedPending) {
                debugViewModel.seedPendingRecordings(context: modelContext)
            }
            debugRow("Trigger foreground upload now",
                     sub: "Calls uploadPending() directly, bypasses BGProcessingTask",
                     key: .uploadTrigger) {
                debugViewModel.triggerForegroundUpload(context: modelContext, dataUpload: dataUpload)
            }
            debugRow("Show upload status",
                     sub: "Alert with counts per status (pending / uploaded / failed / localOnly)",
                     key: .uploadStatus) {
                debugViewModel.showUploadStatus(context: modelContext)
            }
        }
    }

    // MARK: - Danger Zone

    var debugDangerSection: some View {
        Section("Danger Zone") {
            Button("Clear all history") {
                debugViewModel.confirmDanger(
                    title: "Clear all history?",
                    message: "Deletes all CompletedSet records. Cannot be undone."
                ) {
                    debugViewModel.clearAllHistory(context: modelContext)
                }
            }
            .foregroundStyle(.red)

            Button("Reset all enrolments") {
                debugViewModel.confirmDanger(
                    title: "Reset all enrolments?",
                    message: "Resets all exercise progress to Level 1 Day 1. Cannot be undone."
                ) {
                    debugViewModel.resetAllEnrolments(context: modelContext)
                }
            }
            .foregroundStyle(.red)

            Button("Reset done ✓") {
                debugViewModel.resetAllDone()
            }
            .foregroundStyle(.red)
        }
    }

    // MARK: - Row Helper

    private func debugRow(
        _ title: String,
        sub: String,
        key: DebugCheckKey,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(.primary)
                    Text(sub)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(debugViewModel.isDone(key) ? "✓" : "—")
                    .foregroundStyle(debugViewModel.isDone(key) ? Color.green : .secondary)
                    .font(.subheadline)
                    .monospacedDigit()
            }
        }
    }
}
#endif
```

- [ ] **Step 3: Add `DebugPanelSection.swift` to the "inch" Xcode target**

- [ ] **Step 4: Build to verify (expect errors — `DebugViewModel` action stubs missing)**

The build will fail with "value of type 'DebugViewModel' has no member 'setDueToday'" etc. — that's expected. All action methods will be added in Chunks 2–3. To make it compile now, add stub methods at the bottom of `DebugViewModel.swift` (inside the `#if DEBUG` block, inside the class):

```swift
    // MARK: - Action stubs (replaced in Chunks 2–3)
    func setDueToday(context: ModelContext) { markDone(.schedDueToday) }
    func forceRestDay(context: ModelContext) { markDone(.schedRestDay) }
    func setDueTomorrow(context: ModelContext) { markDone(.schedDueTomorrow) }
    func triggerDoubleTestConflict(context: ModelContext) { markDone(.conflictDoubleTest) }
    func triggerSameGroupConflict(context: ModelContext) { markDone(.conflictSameGroup) }
    func setExerciseToTestDay(context: ModelContext) { markDone(.schedTestDay) }
    func advancePushUpsToLevel(_ level: Int, context: ModelContext, key: DebugCheckKey) { markDone(key) }
    func showDemographicsNudge(context: ModelContext) { markDone(.showDemoNudge) }
    func setStreak(_ value: Int, key: DebugCheckKey, context: ModelContext) { markDone(key) }
    func fireDailyReminder() { markDone(.notifDailyReminder) }
    func fireDailyReminderMulti() { markDone(.notifDailyReminderMulti) }
    func fireTestDayReminder() { markDone(.notifTestDay) }
    func fireStreakProtection(streak: Int, key: DebugCheckKey) { markDone(key) }
    func fireLevelUnlock(notificationService: NotificationService) { markDone(.notifLevelUnlock) }
    func fireScheduleAdjustment(notificationService: NotificationService) { markDone(.notifScheduleAdj) }
    func listPendingNotifications() { markDone(.notifList) }
    func seedHistory(weeks: Int, withGaps: Bool, key: DebugCheckKey, context: ModelContext) { markDone(key) }
    func addTestDayResult(passed: Bool, context: ModelContext) { markDone(passed ? .histTestPass : .histTestFail) }
    func simulateWatchReport(context: ModelContext, watchConnectivity: WatchConnectivityService) { markDone(.watchSimReport) }
    func pushScheduleToWatch(context: ModelContext, watchConnectivity: WatchConnectivityService) { markDone(.watchPushSchedule) }
    func logTestHealthKitWorkout(healthKit: HealthKitService) { markDone(.hkLogWorkout) }
    func seedPendingRecordings(context: ModelContext) { markDone(.uploadSeedPending) }
    func triggerForegroundUpload(context: ModelContext, dataUpload: DataUploadService) { markDone(.uploadTrigger) }
    func showUploadStatus(context: ModelContext) { markDone(.uploadStatus) }
    func clearAllHistory(context: ModelContext) {}    // No markDone — Danger Zone actions have no checkmarks
    func resetAllEnrolments(context: ModelContext) {} // No markDone — Danger Zone actions have no checkmarks
```

Re-run the build:

```bash
cd /Users/curtismartin/Work/inch-project/inch
xcodebuild build \
  -project inch.xcodeproj \
  -scheme inch \
  -destination 'generic/platform=iOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Install on device and verify the Developer section appears**

Build and install to device using the existing device build script:

```bash
cd /Users/curtismartin/Work/inch-project
./scripts/build-device.sh
```

Open Settings → scroll to the bottom → confirm "Scheduling & State", "Notifications", "History & Charts", "Watch & HealthKit", "Upload & Sensor Data", "Danger Zone" sections appear. Tap a row — verify `✓` appears next to it. Tap "Reset done ✓" — verify all `✓` marks clear.

- [ ] **Step 6: Commit**

```bash
cd /Users/curtismartin/Work/inch-project
git add inch/inch/Features/Debug/DebugPanelSection.swift \
        inch/inch/Features/Settings/SettingsView.swift \
        inch/inch/Features/Debug/DebugViewModel.swift
git commit -m "feat(debug): add full debug panel UI with stub actions + SettingsView integration"
```

---

## Chunk 2: Scheduling, State & Notification Actions

### Task 5: Scheduling & State action implementations

**Files:**
- Modify: `inch/inch/Features/Debug/DebugViewModel.swift`

Replace each stub with a real implementation. Find the stub methods section added in Task 4 and replace them one by one.

- [ ] **Step 1: Replace `setDueToday`, `forceRestDay`, `setDueTomorrow`**

```swift
func setDueToday(context: ModelContext) {
    let desc = FetchDescriptor<ExerciseEnrolment>(predicate: #Predicate { $0.isActive })
    guard let enrolments = try? context.fetch(desc) else { return }
    for e in enrolments { e.nextScheduledDate = Date.now }
    try? context.save()
    markDone(.schedDueToday)
}

func forceRestDay(context: ModelContext) {
    let tomorrow = Calendar.current.startOfDay(
        for: Calendar.current.date(byAdding: .day, value: 1, to: Date.now) ?? Date.now
    )
    let desc = FetchDescriptor<ExerciseEnrolment>(predicate: #Predicate { $0.isActive })
    guard let enrolments = try? context.fetch(desc) else { return }
    for e in enrolments { e.nextScheduledDate = tomorrow }
    try? context.save()
    markDone(.schedRestDay)
}

func setDueTomorrow(context: ModelContext) {
    let tomorrow = Calendar.current.startOfDay(
        for: Calendar.current.date(byAdding: .day, value: 1, to: Date.now) ?? Date.now
    )
    let desc = FetchDescriptor<ExerciseEnrolment>(predicate: #Predicate { $0.isActive })
    guard let enrolments = try? context.fetch(desc) else { return }
    for e in enrolments { e.nextScheduledDate = tomorrow }
    try? context.save()
    markDone(.schedDueTomorrow)
}
```

- [ ] **Step 2: Replace `triggerDoubleTestConflict`**

Finds the first two active enrolments that have a level definition, sets both to their test day (last day of their current level), scheduled for today.

```swift
func triggerDoubleTestConflict(context: ModelContext) {
    let desc = FetchDescriptor<ExerciseEnrolment>(predicate: #Predicate { $0.isActive })
    guard let enrolments = try? context.fetch(desc) else { return }
    let candidates = enrolments.compactMap { e -> (ExerciseEnrolment, Int)? in
        guard let levelDef = e.exerciseDefinition?.levels?.first(where: { $0.level == e.currentLevel }),
              let totalDays = levelDef.days?.count, totalDays > 0 else { return nil }
        return (e, totalDays)
    }
    guard candidates.count >= 2 else { return }
    for (e, testDay) in candidates.prefix(2) {
        e.currentDay = testDay
        e.nextScheduledDate = Date.now
    }
    try? context.save()
    markDone(.conflictDoubleTest)
}
```

- [ ] **Step 3: Replace `triggerSameGroupConflict`**

Sets Squats to its test day and Glute Bridges to day 1 — both due today. These two exercises are in conflicting muscle groups (`.lower` vs `.lowerPosterior`).

```swift
func triggerSameGroupConflict(context: ModelContext) {
    let desc = FetchDescriptor<ExerciseEnrolment>(predicate: #Predicate { $0.isActive })
    guard let enrolments = try? context.fetch(desc) else { return }
    if let squats = enrolments.first(where: { $0.exerciseDefinition?.exerciseId == "squats" }),
       let levelDef = squats.exerciseDefinition?.levels?.first(where: { $0.level == squats.currentLevel }),
       let totalDays = levelDef.days?.count {
        squats.currentDay = totalDays
        squats.nextScheduledDate = Date.now
    }
    if let glutes = enrolments.first(where: { $0.exerciseDefinition?.exerciseId == "glute_bridges" }) {
        glutes.currentDay = 1
        glutes.nextScheduledDate = Date.now
    }
    try? context.save()
    markDone(.conflictSameGroup)
}
```

- [ ] **Step 4: Replace `setExerciseToTestDay`**

Advances Push-Ups' `currentDay` to the last day of its current level (which is the test day).

```swift
func setExerciseToTestDay(context: ModelContext) {
    let desc = FetchDescriptor<ExerciseEnrolment>(predicate: #Predicate { $0.isActive })
    guard let enrolments = try? context.fetch(desc),
          let pushUps = enrolments.first(where: { $0.exerciseDefinition?.exerciseId == "push_ups" }),
          let levelDef = pushUps.exerciseDefinition?.levels?.first(where: { $0.level == pushUps.currentLevel }),
          let totalDays = levelDef.days?.count else { return }
    pushUps.currentDay = totalDays
    pushUps.nextScheduledDate = Date.now
    try? context.save()
    markDone(.schedTestDay)
}
```

- [ ] **Step 5: Replace `advancePushUpsToLevel`**

```swift
func advancePushUpsToLevel(_ level: Int, context: ModelContext, key: DebugCheckKey) {
    let desc = FetchDescriptor<ExerciseEnrolment>(predicate: #Predicate { $0.isActive })
    guard let enrolments = try? context.fetch(desc),
          let pushUps = enrolments.first(where: { $0.exerciseDefinition?.exerciseId == "push_ups" }) else { return }
    pushUps.currentLevel = level
    pushUps.currentDay = 1
    pushUps.restPatternIndex = 0
    pushUps.nextScheduledDate = Date.now
    try? context.save()
    markDone(key)
}
```

- [ ] **Step 6: Replace `showDemographicsNudge`**

`hasDemographics` is computed from four optional fields — nil all four to make it return `false`.

```swift
func showDemographicsNudge(context: ModelContext) {
    let desc = FetchDescriptor<UserSettings>()
    guard let settings = (try? context.fetch(desc))?.first else { return }
    settings.ageRange = nil
    settings.heightRange = nil
    settings.biologicalSex = nil
    settings.activityLevel = nil
    try? context.save()
    markDone(.showDemoNudge)
}
```

- [ ] **Step 7: Replace `setStreak`**

```swift
func setStreak(_ value: Int, key: DebugCheckKey, context: ModelContext) {
    let desc = FetchDescriptor<StreakState>()
    let existing = (try? context.fetch(desc))?.first
    let state: StreakState
    if let existing {
        state = existing
    } else {
        state = StreakState()
        context.insert(state)
    }
    state.currentStreak = value
    state.longestStreak = value  // Direct assignment — spec requires exact values (e.g., streak0 → longestStreak = 0)
    state.lastActiveDate = value > 0 ? Date.now : nil
    try? context.save()
    markDone(key)
}
```

- [ ] **Step 8: Build to verify**

```bash
cd /Users/curtismartin/Work/inch-project/inch
xcodebuild build \
  -project inch.xcodeproj \
  -scheme inch \
  -destination 'generic/platform=iOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 9: Commit**

```bash
cd /Users/curtismartin/Work/inch-project
git add inch/inch/Features/Debug/DebugViewModel.swift
git commit -m "feat(debug): implement scheduling & state actions"
```

---

### Task 6: Notification action implementations

**Files:**
- Modify: `inch/inch/Features/Debug/DebugViewModel.swift`

- [ ] **Step 1: Add private notification helper**

Add this private helper inside `DebugViewModel` (before the action stubs):

```swift
    private func postDebugNotification(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(identifier: "debug-\(id)-\(UUID().uuidString)",
                                            content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
```

- [ ] **Step 2: Replace all notification stubs**

```swift
func fireDailyReminder() {
    postDebugNotification(id: "daily", title: "Time to train", body: "Push-Ups")
    markDone(.notifDailyReminder)
}

func fireDailyReminderMulti() {
    postDebugNotification(id: "daily-multi", title: "Time to train",
                          body: "3 exercises today — Push-Ups, Squats, Sit-Ups")
    markDone(.notifDailyReminderMulti)
}

func fireTestDayReminder() {
    postDebugNotification(id: "testday", title: "Test day", body: "Push-Ups — max reps today")
    markDone(.notifTestDay)
}

func fireStreakProtection(streak: Int, key: DebugCheckKey) {
    if streak > 1 {
        postDebugNotification(id: "streak-protect", title: "Don't break your streak",
                              body: "\(streak)-day streak — 3 exercises still waiting")
    } else {
        postDebugNotification(id: "streak-protect-0", title: "Start building your streak",
                              body: "3 exercises due today")
    }
    markDone(key)
}

func fireLevelUnlock(notificationService: NotificationService) {
    notificationService.postLevelUnlock(exerciseName: "Push-Ups", newLevel: 2, startsIn: 2)
    markDone(.notifLevelUnlock)
}

func fireScheduleAdjustment(notificationService: NotificationService) {
    notificationService.postScheduleAdjustment(exerciseName: "Push-Ups", newDateDescription: "tomorrow")
    markDone(.notifScheduleAdj)
}

func listPendingNotifications() {
    Task {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        alertTitle = "Pending Notifications (\(pending.count))"
        alertMessage = pending.isEmpty
            ? "None scheduled"
            : pending.map(\.identifier).joined(separator: "\n")
        showAlert = true
        markDone(.notifList)  // Inside Task — checkmark set after async fetch completes
    }
}
```

- [ ] **Step 3: Build to verify**

```bash
cd /Users/curtismartin/Work/inch-project/inch
xcodebuild build \
  -project inch.xcodeproj \
  -scheme inch \
  -destination 'generic/platform=iOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
cd /Users/curtismartin/Work/inch-project
git add inch/inch/Features/Debug/DebugViewModel.swift
git commit -m "feat(debug): implement notification actions"
```

---

## Chunk 3: History, Watch, Upload & Danger Zone Actions

### Task 7: History seeding action implementations

**Files:**
- Modify: `inch/inch/Features/Debug/DebugViewModel.swift`

- [ ] **Step 1: Add private `insertSets` helper**

```swift
    private func insertSets(
        exerciseId: String,
        level: Int,
        dayNumber: Int,
        setCount: Int,
        repsPerSet: Int,
        sessionDate: Date,
        context: ModelContext
    ) {
        for i in 1...setCount {
            context.insert(CompletedSet(
                completedAt: sessionDate,
                sessionDate: sessionDate,
                exerciseId: exerciseId,
                level: level,
                dayNumber: dayNumber,
                setNumber: i,
                targetReps: repsPerSet,
                actualReps: repsPerSet
            ))
        }
    }
```

- [ ] **Step 2: Replace `seedHistory`**

Seeds workouts for Push-Ups, Squats, and Sit-Ups in rotation. One workout every 2–3 days (pattern 2, 2, 3, repeating). If `withGaps` is true, skips 5 consecutive days in the middle of the range to create the gap that triggers "Pushed to tomorrow" labels.

```swift
func seedHistory(weeks: Int, withGaps: Bool, key: DebugCheckKey, context: ModelContext) {
    let exercises: [(id: String, reps: Int)] = [
        (id: "push_ups", reps: 10),
        (id: "squats",   reps: 12),
        (id: "sit_ups",  reps: 10),
    ]
    var dayNumbers = [String: Int]()
    exercises.forEach { dayNumbers[$0.id] = 1 }

    let totalCalendarDays = weeks * 7
    let gapStart = totalCalendarDays / 2       // gap begins here
    let gapEnd   = gapStart + 5                // 5-day gap

    var calendarOffset = 0
    var workoutCount = 0

    while calendarOffset < totalCalendarDays {
        if withGaps && calendarOffset >= gapStart && calendarOffset < gapEnd {
            calendarOffset += 1
            continue
        }
        let ex = exercises[workoutCount % exercises.count]
        let daysAgo = totalCalendarDays - calendarOffset
        let sessionDate = Calendar.current.date(
            byAdding: .day,
            value: -daysAgo,
            to: Calendar.current.startOfDay(for: Date.now)
        ) ?? Date.now

        let dn = dayNumbers[ex.id] ?? 1
        insertSets(exerciseId: ex.id, level: 1, dayNumber: dn,
                   setCount: 3, repsPerSet: ex.reps, sessionDate: sessionDate, context: context)
        dayNumbers[ex.id] = dn + 1
        workoutCount += 1

        // Rest pattern: 2, 2, 3, 2, 2, 3...
        calendarOffset += (workoutCount % 3 == 0) ? 3 : 2
    }
    try? context.save()
    markDone(key)
}
```

- [ ] **Step 3: Replace `addTestDayResult`**

```swift
func addTestDayResult(passed: Bool, context: ModelContext) {
    context.insert(CompletedSet(
        completedAt: Date.now,
        sessionDate: Date.now,
        exerciseId: "push_ups",
        level: 1,
        dayNumber: 10,
        setNumber: 1,
        targetReps: 50,
        actualReps: passed ? 55 : 43,
        isTest: true,
        testPassed: passed
    ))
    try? context.save()
    markDone(passed ? .histTestPass : .histTestFail)
}
```

- [ ] **Step 4: Build to verify**

```bash
cd /Users/curtismartin/Work/inch-project/inch
xcodebuild build \
  -project inch.xcodeproj \
  -scheme inch \
  -destination 'generic/platform=iOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
cd /Users/curtismartin/Work/inch-project
git add inch/inch/Features/Debug/DebugViewModel.swift
git commit -m "feat(debug): implement history seeding actions"
```

---

### Task 8: Watch & HealthKit action implementations

**Files:**
- Modify: `inch/inch/Features/Debug/DebugViewModel.swift`

- [ ] **Step 1: Replace `simulateWatchReport`**

```swift
func simulateWatchReport(context: ModelContext, watchConnectivity: WatchConnectivityService) {
    let report = WatchCompletionReport(
        exerciseId: "push_ups",
        level: 1,
        dayNumber: 1,
        completedSets: [
            WatchSetResult(setNumber: 1, targetReps: 10, actualReps: 10, durationSeconds: 30),
            WatchSetResult(setNumber: 2, targetReps: 10, actualReps: 10, durationSeconds: 28),
            WatchSetResult(setNumber: 3, targetReps: 10, actualReps: 10, durationSeconds: 32),
        ],
        completedAt: Date.now
    )
    watchConnectivity.simulateCompletionReport(report)
    markDone(.watchSimReport)
}
```

- [ ] **Step 2: Replace `pushScheduleToWatch`**

```swift
func pushScheduleToWatch(context: ModelContext, watchConnectivity: WatchConnectivityService) {
    let enrolmentsDesc = FetchDescriptor<ExerciseEnrolment>(predicate: #Predicate { $0.isActive })
    let enrolments = (try? context.fetch(enrolmentsDesc)) ?? []
    let settings = (try? context.fetch(FetchDescriptor<UserSettings>()))?.first
    watchConnectivity.sendTodaySchedule(enrolments: enrolments, settings: settings)
    markDone(.watchPushSchedule)
}
```

- [ ] **Step 3: Replace `logTestHealthKitWorkout`**

```swift
func logTestHealthKitWorkout(healthKit: HealthKitService) {
    Task {
        await healthKit.requestAuthorization()
        let end = Date.now
        let start = end.addingTimeInterval(-600) // 10 minutes ago
        await healthKit.saveWorkout(
            startDate: start,
            endDate: end,
            totalEnergyBurned: nil,
            metadata: [:]
        )
        markDone(.hkLogWorkout)
    }
}
```

- [ ] **Step 4: Build to verify**

```bash
cd /Users/curtismartin/Work/inch-project/inch
xcodebuild build \
  -project inch.xcodeproj \
  -scheme inch \
  -destination 'generic/platform=iOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
cd /Users/curtismartin/Work/inch-project
git add inch/inch/Features/Debug/DebugViewModel.swift
git commit -m "feat(debug): implement watch and HealthKit actions"
```

---

### Task 9: Upload & Sensor Data action implementations

**Files:**
- Modify: `inch/inch/Features/Debug/DebugViewModel.swift`

- [ ] **Step 1: Replace `seedPendingRecordings`**

Writes 3 stub binary files to `Documents/sensor_data/` and inserts matching `SensorRecording` rows with `uploadStatus = .pending`. The `filePath` on each recording must point to the stub file — without it, `uploadPending` will immediately mark them `.localOnly`.

```swift
func seedPendingRecordings(context: ModelContext) {
    let sensorDir = URL.documentsDirectory.appending(path: "sensor_data", directoryHint: .isDirectory)
    try? FileManager.default.createDirectory(at: sensorDir, withIntermediateDirectories: true)

    let stubData = Data(count: 1024)
    for i in 1...3 {
        let fileURL = sensorDir.appending(path: "debug_stub_\(i).bin")
        try? stubData.write(to: fileURL)
        context.insert(SensorRecording(
            recordedAt: Date.now,
            device: .iPhone,
            exerciseId: "push_ups",
            level: 1,
            dayNumber: 1,
            setNumber: i,
            confirmedReps: 10,
            sampleRateHz: 50,
            durationSeconds: 30,
            countingMode: "post_set_confirmation",
            filePath: fileURL.path,
            fileSizeBytes: 1024,
            sessionId: UUID().uuidString,
            uploadStatus: .pending
        ))
    }
    try? context.save()
    markDone(.uploadSeedPending)
}
```

- [ ] **Step 2: Replace `triggerForegroundUpload`**

```swift
func triggerForegroundUpload(context: ModelContext, dataUpload: DataUploadService) {
    Task {
        await dataUpload.uploadPending(context: context)
        markDone(.uploadTrigger)
    }
}
```

- [ ] **Step 3: Replace `showUploadStatus`**

```swift
func showUploadStatus(context: ModelContext) {
    let recordings = (try? context.fetch(FetchDescriptor<SensorRecording>())) ?? []
    let grouped = Dictionary(grouping: recordings, by: \.uploadStatus)
    let statuses: [UploadStatus] = [.pending, .uploading, .uploaded, .failed, .localOnly]
    let lines = statuses.compactMap { status -> String? in
        let count = grouped[status]?.count ?? 0
        guard count > 0 else { return nil }
        return "\(status.rawValue): \(count)"
    }
    alertTitle = "Upload Status (\(recordings.count) total)"
    alertMessage = lines.isEmpty ? "No recordings found" : lines.joined(separator: "\n")
    showAlert = true
    markDone(.uploadStatus)
}
```

- [ ] **Step 4: Build to verify**

```bash
cd /Users/curtismartin/Work/inch-project/inch
xcodebuild build \
  -project inch.xcodeproj \
  -scheme inch \
  -destination 'generic/platform=iOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
cd /Users/curtismartin/Work/inch-project
git add inch/inch/Features/Debug/DebugViewModel.swift
git commit -m "feat(debug): implement upload and sensor data actions"
```

---

### Task 10: Danger Zone action implementations

**Files:**
- Modify: `inch/inch/Features/Debug/DebugViewModel.swift`

- [ ] **Step 1: Replace `clearAllHistory` and `resetAllEnrolments`**

```swift
func clearAllHistory(context: ModelContext) {
    let sets = (try? context.fetch(FetchDescriptor<CompletedSet>())) ?? []
    for set in sets { context.delete(set) }
    try? context.save()
}

func resetAllEnrolments(context: ModelContext) {
    let desc = FetchDescriptor<ExerciseEnrolment>(predicate: #Predicate { $0.isActive })
    let enrolments = (try? context.fetch(desc)) ?? []
    for e in enrolments {
        e.currentLevel = 1
        e.currentDay = 1
        e.restPatternIndex = 0
        e.lastCompletedDate = nil
        e.nextScheduledDate = Date.now
    }
    try? context.save()
}
```

- [ ] **Step 2: Final build to verify everything compiles**

```bash
cd /Users/curtismartin/Work/inch-project/inch
xcodebuild build \
  -project inch.xcodeproj \
  -scheme inch \
  -destination 'generic/platform=iOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Install on device and do a final smoke test**

```bash
cd /Users/curtismartin/Work/inch-project
./scripts/build-device.sh
```

On device, verify:
1. Settings → Developer section visible
2. Tap "Set exercises due today" → ✓ appears → navigate to Today tab → exercises appear
3. Tap "Force rest day" → ✓ appears → Today tab shows RestDayView
4. Tap "Set streak → 7 days" → ✓ appears → RestDayView shows flame badge
5. Tap "Fire streak protection (streak = 7) now" → ✓ appears → lock screen → notification arrives in ~3 seconds
6. Tap "Seed 4 weeks of history" → ✓ → History tab → Log and Stats both show data
7. Tap "Reset done ✓" → all ✓ marks clear
8. Tap "Clear all history" → confirm alert appears → confirm → History tab empties

- [ ] **Step 4: Final commit**

```bash
cd /Users/curtismartin/Work/inch-project
git add inch/inch/Features/Debug/DebugViewModel.swift
git commit -m "feat(debug): implement danger zone actions — debug panel complete"
```
