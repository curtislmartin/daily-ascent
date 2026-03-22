# Debug Panel — Design Spec

**Date:** 2026-03-22
**Status:** Approved

---

## Overview

A developer-only debug panel for physical device testing. Provides buttons to seed data, trigger notifications, and put the app into specific states that would otherwise take days of real usage to reach. Compiled out entirely from production builds with `#if DEBUG`. Removed from the codebase after testing is complete (source preserved in git history).

---

## Access Point

A "Developer" `Section` added at the bottom of the existing `List` in `SettingsView`, visible only inside a `#if DEBUG` block. `DebugPanelSection` renders as one or more `Section` blocks — not as a standalone `ScrollView` — so it embeds cleanly inside the existing `.insetGrouped` list. Tapping any row performs the action immediately, then marks it done. No push navigation.

---

## Progress Tracking

Each action has a checkmark state stored in `UserDefaults` under a stable string key (e.g., `"debug.forceRestDay"`).

- Not done: trailing `—` in secondary grey
- Done: trailing `✓` in green (`Color.green`)
- Actions remain fully tappable when checked — the checkmark is informational only
- "Reset Done ✓" in the Danger Zone removes all `UserDefaults` keys with the `"debug."` prefix

---

## Architecture

### New Files (iOS target only)

| File | Purpose |
|---|---|
| `Features/Debug/DebugPanelSection.swift` | One or more `Section { }` blocks — the rows. Embedded in `SettingsView` inside `#if DEBUG`. |
| `Features/Debug/DebugViewModel.swift` | `@Observable` class. Holds all action implementations and checkmark state. |
| `Features/Debug/DebugCheckKey.swift` | `enum DebugCheckKey: String` with one case per action. Raw values are the `UserDefaults` keys. |

### Integration

`SettingsView` gains a `#if DEBUG` block after `privacySection`:

```swift
#if DEBUG
DebugPanelSection(viewModel: debugViewModel)
#endif
```

`DebugViewModel` is created with `@State private var debugViewModel = DebugViewModel()` in `SettingsView` and receives `modelContext`, `notificationService`, `watchConnectivityService`, and `healthKitService` via method parameters on each action call. This keeps `DebugViewModel.init()` parameter-free, which is required for `@State` initialisation. Since `DebugViewModel` is `@Observable` and implicitly `@MainActor` in this target, all action methods already run on the main actor — passing `@MainActor`-bound values as non-`@escaping` parameters is valid under Swift 6 strict concurrency.

All four services are already injected into the environment by `InchApp` via `.environment(...)`. `SettingsView` retrieves them with `@Environment` properties:

```swift
@Environment(NotificationService.self) private var notificationService
@Environment(WatchConnectivityService.self) private var watchConnectivity
@Environment(HealthKitService.self) private var healthKit
@Environment(DataUploadService.self) private var dataUpload
```

These are passed as arguments to `DebugPanelSection`, which forwards them to `DebugViewModel` action methods.

### Service Changes Required

Two existing services need minor additions to support debug injection:

**`WatchConnectivityService`** — add an internal method:
```swift
func simulateCompletionReport(_ report: WatchCompletionReport) {
    _completionReports.yield(report)
}
```

**`DataUploadService`** — change `private func uploadPending(context:)` to `internal func uploadPending(context:)` so `DebugViewModel` can call it directly.

---

## Sections & Actions

### Scheduling & State

| Action | What it does | Key |
|---|---|---|
| Set exercises due today | Sets `nextScheduledDate = Date.now` on all active `ExerciseEnrolment`s, then calls `context.save()` | `schedDueToday` |
| Force rest day | Sets `nextScheduledDate` to start-of-tomorrow on all active enrolments → `TodayViewModel.isRestDay` becomes `true` | `schedRestDay` |
| Set exercises due tomorrow | Sets `nextScheduledDate` to start-of-tomorrow — same mutation as "Force rest day", separate checkmark for tracking that you verified the RestDayView "next training tomorrow" subtext specifically | `schedDueTomorrow` |
| Trigger double-test conflict | Finds two enrolments from different exercise IDs whose current level has a test day, sets both `currentDay` to their test day number and `nextScheduledDate = Date.now` | `conflictDoubleTest` |
| Trigger same-group conflict | Sets Squats to its current level's test day (`currentDay = level.totalDays`, `nextScheduledDate = Date.now`) and Glute Bridges to `currentDay = 1` (always a training day, never a test), `nextScheduledDate = Date.now`. Squats is `.lower` and Glute Bridges is `.lowerPosterior` — these two groups conflict per `MuscleGroup.conflictGroups`. Result: Glute Bridges card shows "Same muscle group as today's test". | `conflictSameGroup` |
| Set exercise to test day | Finds the `LevelDefinition` for Push-Ups at `currentLevel`; sets `currentDay` to that level's last day number (the test day) and `nextScheduledDate = Date.now` | `schedTestDay` |
| Advance exercise to L2 | Sets Push-Ups: `currentLevel = 2`, `currentDay = 1`, `restPatternIndex = 0`, `nextScheduledDate = Date.now` | `advanceL2` |
| Advance exercise to L3 | Sets Push-Ups: `currentLevel = 3`, `currentDay = 1`, `restPatternIndex = 0`, `nextScheduledDate = Date.now` | `advanceL3` |
| Show demographics nudge | Sets `UserSettings.hasDemographics = false`, saves context | `showDemoNudge` |
| Set streak → 0 | Sets `StreakState.currentStreak = 0`, `longestStreak = 0`, `lastActiveDate = nil`, saves | `streak0` |
| Set streak → 1 day | Sets `currentStreak = 1`, `longestStreak = 1`, `lastActiveDate = Date.now`, saves | `streak1` |
| Set streak → 7 days | Sets `currentStreak = 7`, `longestStreak = 7`, `lastActiveDate = Date.now`, saves | `streak7` |
| Set streak → 30 days | Sets `currentStreak = 30`, `longestStreak = 30`, `lastActiveDate = Date.now`, saves | `streak30` |

### Notifications

Most debug notifications are posted directly via `UNUserNotificationCenter.current().add(_:)`, bypassing `NotificationService`. This is intentional: production scheduling uses `UNCalendarNotificationTrigger`; debug actions use `UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)` so you can lock the screen and see them arrive in ~3 seconds.

**Exceptions:** `notifLevelUnlock` and `notifScheduleAdj` call through `NotificationService` directly, since it already has public `postLevelUnlock(exerciseName:newLevel:startsIn:)` and `postScheduleAdjustment(exerciseName:newDateDescription:)` methods that produce the correct content.

| Action | Title | Body | Key |
|---|---|---|---|
| Fire daily reminder now | "Time to train" | "Push-Ups" | `notifDailyReminder` |
| Fire daily reminder (multi) now | "Time to train" | "3 exercises today — Push-Ups, Squats, Sit-Ups" | `notifDailyReminderMulti` |
| Fire test-day reminder now | "Test day" | "Push-Ups — max reps today" | `notifTestDay` |
| Fire streak protection (streak = 0) now | "Start building your streak" | "3 exercises due today" | `notifStreakProtect0` |
| Fire streak protection (streak = 7) now | "Don't break your streak" | "7-day streak — 3 exercises still waiting" | `notifStreakProtect7` |
| Fire level unlock now | "Level 2 unlocked!" | "Push-Ups — Level 2 starts in 2 days" | `notifLevelUnlock` |
| Fire schedule adjustment now | "Schedule adjusted" | "Push-Ups moved to tomorrow" | `notifScheduleAdj` |
| List pending notifications | — | Fetches `pendingNotificationRequests()`, shows count + identifiers in an alert | `notifList` |

### History & Charts

Seeded `CompletedSet` records use realistic rep counts from the L1 prescriptions for Push-Ups, Squats, and Sit-Ups (3 exercises is enough to populate all chart views). Session dates are backdated from today using `Calendar.current.date(byAdding:)`.

| Action | What it does | Key |
|---|---|---|
| Seed 4 weeks of history | Inserts `CompletedSet` records for Push-Ups, Squats, Sit-Ups on a 2–3 day alternating schedule over 28 days | `histSeed4w` |
| Seed 12 weeks of history | Same pattern, 84 days — tests chart scrolling and week group headers | `histSeed12w` |
| Seed history with missed days | 4 weeks with deliberate 3–5 day gaps mid-sequence — verifies "Pushed to tomorrow" labels and streak reset logic | `histSeedGaps` |
| Add test day pass to history | Inserts one `CompletedSet` with `isTest = true`, `testPassed = true`, `actualReps = 55`, `targetReps = 50` for Push-Ups, `sessionDate = Date.now` | `histTestPass` |
| Add test day fail to history | Inserts one `CompletedSet` with `isTest = true`, `testPassed = false`, `actualReps = 43`, `targetReps = 50` for Push-Ups, `sessionDate = Date.now` | `histTestFail` |

### Watch & HealthKit

| Action | What it does | Key |
|---|---|---|
| Simulate watch completion report | Constructs a `WatchCompletionReport` for Push-Ups L1 D1 with 3 sets (10/10/10 reps), calls `watchConnectivity.simulateCompletionReport(_:)` | `watchSimReport` |
| Push today's schedule to watch | Calls `watchConnectivity.sendTodaySchedule(enrolments:settings:)` with the current live enrolments and settings | `watchPushSchedule` |
| Log test HealthKit workout | Calls `healthKitService.requestAuthorization()`, then `healthKitService.saveWorkout(startDate: Date.now.addingTimeInterval(-600), endDate: Date.now, totalEnergyBurned: nil, metadata: [:])` | `hkLogWorkout` |

### Upload & Sensor Data

| Action | What it does | Key |
|---|---|---|
| Seed fake sensor recordings (pending) | Writes 1 KB stub binary files (`Data(count: 1024)`) to `URL.documentsDirectory.appending(path: "sensor_data/debug_stub_N.bin")` for N in 1–3. Inserts 3 `SensorRecording` objects with `uploadStatus = .pending` and `filePath` set to the full path of each stub file (e.g., `.documentsDirectory.appending(path: "sensor_data/debug_stub_1.bin").path`). The `filePath` linkage is required — without it `uploadPending` will immediately mark records `.localOnly` because `FileManager.fileExists` will return false. | `uploadSeedPending` |
| Trigger foreground upload now | Calls `uploadService.uploadPending(context:)` directly (method made `internal`) | `uploadTrigger` |
| Show upload status | Fetches all `SensorRecording`s, groups by `uploadStatus`, displays counts in an alert: `"pending: 3, uploaded: 12, failed: 0, localOnly: 1"` | `uploadStatus` |

### Danger Zone

No checkmarks. All rows show a destructive confirmation alert before executing.

| Action | What it does | Alert message |
|---|---|---|
| Clear all history | Deletes all `CompletedSet` records from context, saves | "Deletes all CompletedSet records. Cannot be undone." |
| Reset all enrolments | Sets all `ExerciseEnrolment`: `currentLevel = 1`, `currentDay = 1`, `restPatternIndex = 0`, `lastCompletedDate = nil`, `nextScheduledDate = Date.now`, saves | "Resets all exercise progress to Level 1 Day 1. Cannot be undone." |
| Reset done ✓ | Iterates all `DebugCheckKey` cases and removes each from `UserDefaults`. No data is changed. | None — no confirmation needed, non-destructive |

---

## Production Exclusion

The panel is excluded from production at the call site in `SettingsView`:

```swift
#if DEBUG
DebugPanelSection(viewModel: debugViewModel)
#endif
```

`DebugPanelSection.swift`, `DebugViewModel.swift`, and `DebugCheckKey.swift` are in the Xcode target with no special compiler flags — Swift's dead-code elimination handles the rest.

After device testing is complete: delete the three debug files and remove the `#if DEBUG` block from `SettingsView`. The code is preserved in git history.

---

## Out of Scope

- **Onboarding reset** — resetting to pre-onboarding state risks data loss and can be done via Xcode device management
- **Watch app debug panel** — watch has limited screen real estate; no companion panel planned
- **Simulator** — scheduling logic, conflict detection, and streak calculation are covered by unit tests in the Shared package
