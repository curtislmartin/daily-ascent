# Watch App Enhancements Design

## Overview

Enrich the watchOS app with live heart rate during workouts, a history tab showing recent completed workouts, and a settings tab for watch-only preferences. The goal is to make the watch feel like a first-class workout companion — not just a remote control for the phone.

---

## Architecture

### New Components

**`WatchSettings`** (`WatchSettings.swift`)
- `@Observable @MainActor final class`. Properties persisted to UserDefaults via `didSet`. All four keys loaded in `init()`:
  ```swift
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
- Note: `didSet` does not fire during `init` in Swift, so loading in `init()` is safe and does not double-write.
- Injected at app root via `.environment()`

**`WatchHealthService`** (`WatchHealthService.swift`)
- `@Observable @MainActor final class`
- Manages `HKWorkoutSession` + `HKLiveWorkoutBuilder` for live heart rate
- Publishes `currentBPM: Int?` — `nil` until first HR sample received or if HealthKit not authorized
- Publishes `isAuthorized: Bool` — drives conditional display of HR settings
- `func requestAuthorization() async` — requests HealthKit read/write for heart rate + workout
- `func startWorkout() async` — calls `requestAuthorization()` first if not yet authorized, then begins `HKWorkoutSession` with `.functionalStrengthTraining`
- `func endWorkout() async` — calls `HKLiveWorkoutBuilder.endCollection(withEnd:)` and `HKWorkoutSession.end()` in sequence, awaited before returning
- Authorization is requested lazily inside `startWorkout()` (not at app launch)
- Workout session lifecycle activates watchOS always-on display automatically on supported hardware
- **Threading:** `HKWorkoutBuilderDelegate.workoutBuilder(_:didCollectDataOf:)` fires on HealthKit's background queue. Bridge to main actor via `Task { @MainActor in self.currentBPM = latestBPM }`. Do not use `@unchecked Sendable`.

**`WatchHistoryStore`** (`WatchHistoryStore.swift`)
- `@Observable @MainActor final class`
- UserDefaults key: `"watch.historyEntries"` (stores `[WatchHistoryEntry]` as JSON)
- Stores up to 30 entries (oldest dropped when over limit)
- `func record(_ report: WatchCompletionReport, exerciseName: String)` — called from `WatchWorkoutView` before `dismiss()`
- `var entries: [WatchHistoryEntry]` — sorted newest first
- On load, if JSON decode fails for any reason, `entries` defaults to `[]` (never crash)

**`WatchHistoryEntry`** (`WatchHistoryEntry.swift` — own file per project convention)
- `Codable` struct
- Properties: `id: UUID`, `exerciseName: String`, `level: Int`, `dayNumber: Int`, `totalReps: Int`, `setCount: Int`, `completedAt: Date`

### App Shell Changes

**Deployment target note:** This spec uses the `Tab` view type (not the legacy `.tabItem` modifier). `Tab` requires watchOS 11+. The project deployment target is watchOS 11.0 — this is correct.

`inchwatchApp.swift` changes from a single `WatchTodayView` `WindowGroup` to a `TabView` with three named tabs:

```swift
TabView {
    Tab("Today", systemImage: "figure.strengthtraining.traditional") { WatchTodayView() }
    Tab("History", systemImage: "clock") { WatchHistoryView() }
    Tab("Settings", systemImage: "gearshape") { WatchSettingsView() }
}
```

All services (`WatchConnectivityService`, `WatchMotionRecordingService`, `WatchHealthService`, `WatchHistoryStore`, `WatchSettings`) injected via `.environment()` at the app root.

**Important:** `WatchTodayView` currently uses an internal `TabView { ... }.tabViewStyle(.page)` to page between exercises. Nesting a `TabView` inside another `TabView` is unsupported on watchOS. Replace the internal paging `TabView` with a `List` of exercise cards.

---

## Today + Workout Enhancements

### Today Tab

`WatchTodayView` replaces its internal paging `TabView` with a `List`. `WatchSettings` is read from environment here and passed as a constructor argument to `WatchWorkoutView` (since environment values cannot be read inside another view's `init`):

```swift
struct WatchTodayView: View {
    @Environment(WatchConnectivityService.self) private var watchConnectivity
    @Environment(WatchMotionRecordingService.self) private var motionRecording
    @Environment(WatchSettings.self) private var settings
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
                        Text(session.exerciseName).font(.headline)
                        Text("Level \(session.level) · Day \(session.dayNumber)")
                            .font(.caption).foregroundStyle(.secondary)
                        if session.isTest {
                            Text("TEST DAY").font(.caption2).fontWeight(.bold).foregroundStyle(.orange)
                        }
                    }
                }
            }
            .sheet(item: $activeSession) { session in
                WatchWorkoutView(session: session, settings: settings)
            }
        }
    }
}
```

Empty state (rest day view) is unchanged.

### Workout — Live Heart Rate

`WatchWorkoutView` receives `WatchSettings` as an explicit init parameter (not from environment, since environment is unavailable during `init` where the view model is constructed). `WatchHealthService` and `WatchHistoryStore` are read from environment in `body`.

```swift
struct WatchWorkoutView: View {
    let session: WatchSession
    @Environment(WatchConnectivityService.self) private var watchConnectivity
    @Environment(WatchMotionRecordingService.self) private var motionRecording
    @Environment(WatchHealthService.self) private var healthService
    @Environment(WatchHistoryStore.self) private var historyStore
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: WatchWorkoutViewModel

    init(session: WatchSession, settings: WatchSettings) {
        self.session = session
        _viewModel = State(initialValue: WatchWorkoutViewModel(session: session, settings: settings))
    }
    ...
}
```

**Heart rate indicator:**
- Add `.overlay(alignment: .topTrailing)` to the outermost container of `inSetView` and `WatchRealTimeCountingView`
- Overlay content: `Text("♥ \(bpm)").font(.caption2).foregroundStyle(.red)` (shown only when `currentBPM != nil && showHeartRate == true`)

**startWorkout() call site:**
- In `WatchWorkoutView`, detect when the first set begins. In the "Start" button action of `readyView`:
  ```swift
  Button("Start") {
      if viewModel.completedSets.isEmpty {
          Task { await healthService.startWorkout() }
      }
      setStartDate = .now
      viewModel.startSet()
  }
  ```
- Guard condition: only call `startWorkout()` when `viewModel.completedSets.isEmpty` (i.e. first set). Subsequent set starts do not re-invoke it.

**HR alert** (in `WatchWorkoutView` body, observed via `onChange`):
- `onChange(of: healthService.currentBPM)` — if `settings.heartRateAlertBPM > 0` and `bpm >= settings.heartRateAlertBPM` and `!hasAlerted`, play `.notification` haptic and set `hasAlerted = true`. When BPM drops below threshold, reset `hasAlerted = false`.

### Workout — Auto-Advance After Rest

`WatchWorkoutViewModel` takes `WatchSettings` at init. `finishRest()` checks `settings.autoAdvanceAfterRest`:
- `true` → transition to `.inSet(startedAt: .now)` directly
- `false` → transition to `.ready` (existing behaviour)

### Workout — Completion Flow

In `WatchWorkoutView`'s `onDone` closure (passed to `WatchExerciseCompleteView`), call in order inside a `Task`:

```swift
onDone: {
    Task {
        historyStore.record(viewModel.completionReport, exerciseName: session.exerciseName)
        watchConnectivity.sendCompletionReport(viewModel.completionReport)
        await healthService.endWorkout()
        dismiss()
    }
}
```

`endWorkout()` is `async` and must be awaited before `dismiss()` to ensure the workout is saved to Health before the view disappears.

### Rest Timer — Haptic Countdown

`WatchRestTimerView` receives `WatchSettings` from environment.

If `WatchSettings.hapticFinalCountdown == true`, play `WKInterfaceDevice.current().play(.click)` at 3, 2, and 1 seconds remaining. These are in addition to the existing 10-second notification haptic and the triple-success at 0.

---

## History Tab

### `WatchHistoryView`

- `List` of `WatchHistoryStore.entries`, grouped into sections by calendar day
- Section headers: "Today", "Yesterday", or short date (e.g. "Mar 12")
- Each row: exercise name, "42 reps · 3 sets", relative time (e.g. "14 min ago")
- Tapping a row presents a detail sheet

### History Detail Sheet

- Exercise name (headline)
- "Level X · Day Y" (subheadline)
- Total reps (bold)
- Set count
- Full date + time of completion
- **No per-set breakdown** — only summary totals are stored; per-set division would be misleading
- Dismiss via swipe

### Empty State

Full-screen: "No workouts yet" + "Complete one from the Today tab."

---

## Settings Tab

`WatchSettingsView` — a `List` with two sections:

**Heart Rate** (entire section hidden if `WatchHealthService.isAuthorized == false`)
- Toggle: "Show heart rate" → `WatchSettings.showHeartRate`
- Picker: "High HR alert" — Off / 150 BPM / 160 BPM / 170 BPM / 180 BPM, `.pickerStyle(.navigationLink)`
  - `heartRateAlertBPM` value `0` maps to "Off"

**Workout**
- Toggle: "Auto-start next set" → `WatchSettings.autoAdvanceAfterRest`
  - Footer: "Skips the ready screen and begins the next set automatically after rest ends."
- Toggle: "Countdown haptics" → `WatchSettings.hapticFinalCountdown`
  - Footer: "Taps your wrist at 3, 2, and 1 seconds remaining in the rest timer."

---

## HealthKit Requirements

**Entitlements** — create `inchwatch Watch App/inchwatch.entitlements`:
```xml
<key>com.apple.developer.healthkit</key>
<true/>
<key>com.apple.developer.healthkit.access</key>
<array/>
```

**Info.plist** (watch target):
- `NSHealthShareUsageDescription` — "Daily Ascent reads your heart rate during workouts."
- `NSHealthUpdateUsageDescription` — "Daily Ascent saves your strength workouts to the Health app."

**Read types**: `HKQuantityType(.heartRate)`
**Write types**: `HKObjectType.workoutType()` only — the app does not write HR samples directly; `HKLiveWorkoutBuilder` collects them automatically

---

## Files

| Action | File |
|--------|------|
| Create | `inchwatch Watch App/Models/WatchSettings.swift` |
| Create | `inchwatch Watch App/Models/WatchHistoryEntry.swift` |
| Create | `inchwatch Watch App/Models/WatchHistoryStore.swift` |
| Create | `inchwatch Watch App/Services/WatchHealthService.swift` |
| Create | `inchwatch Watch App/Features/WatchHistoryView.swift` |
| Create | `inchwatch Watch App/Features/WatchSettingsView.swift` |
| Create | `inchwatch Watch App/inchwatch.entitlements` |
| Modify | `inchwatch Watch App/inchwatchApp.swift` |
| Modify | `inchwatch Watch App/Features/WatchTodayView.swift` |
| Modify | `inchwatch Watch App/Features/WatchWorkoutView.swift` |
| Modify | `inchwatch Watch App/Features/WatchWorkoutViewModel.swift` |
| Modify | `inchwatch Watch App/Features/WatchRestTimerView.swift` |
| Modify | `inchwatch Watch App/Features/WatchRealTimeCountingView.swift` |
| Modify | `inch.xcodeproj/project.pbxproj` (HealthKit entitlement reference, new files) |

---

## Out of Scope

- Syncing watch history back to the phone (phone has authoritative history via SwiftData)
- Complications (separate feature)
- Crown rotation for rep input (separate feature)
