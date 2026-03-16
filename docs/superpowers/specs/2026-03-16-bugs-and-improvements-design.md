# Bugs & Improvements Design — v1 Polish

## Goal

Fix all bugs identified in user testing and improve visual polish across iOS and watchOS.

## Architecture

Changes are isolated to existing view and view model files. No new data model entities required. Stats chart redesign replaces `HistoryStatsView` internals and adds a `daysTrainedThisWeek` property to `HistoryStats`. Watch layout fixes are targeted per-view.

## Tech Stack

SwiftUI, Swift Charts, SF Symbols, SwiftData, existing app architecture.

---

## Section 1: iOS Bug Fixes

### 1.1 Appearance Picker Stale State

**Problem:** `SettingsView.appearanceSection` constructs a manual `Binding(get:set:)` inside `if let settings = viewModel.settings`. When settings changes identity, the picker is re-created mid-interaction, causing rapid second selection changes to not propagate.

**Fix:** Extract `appearanceSection` into a private subview `AppearanceSectionView` that takes `@Bindable var settings: UserSettings`. Add `@Environment(\.modelContext) private var modelContext` to the subview and call `try? modelContext.save()` via `.onChange(of: settings.appearanceMode)`:

```swift
private struct AppearanceSectionView: View {
    @Bindable var settings: UserSettings
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Section("Appearance") {
            Picker("Theme", selection: $settings.appearanceMode) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            .pickerStyle(.segmented)
            .onChange(of: settings.appearanceMode) {
                try? modelContext.save()
            }
        }
    }
}
```

Call site in `SettingsView.body`: replace the existing `appearanceSection` computed property call with `if let s = viewModel.settings { AppearanceSectionView(settings: s) }`.

**Files:** `inch/inch/Features/Settings/SettingsView.swift`

### 1.2 Streak Not Resetting on Delete History or Reset App

**Problem:** Neither `deleteHistory` nor `resetToOnboarding` resets `StreakState`. After deleting history, streak displays stale values (e.g. current: 1, best: 2). After resetting the app, streak persists across what should be a clean slate (note: `resetToOnboarding` deletes `UserSettings`, `ExerciseEnrolment`, and `CompletedSet`, but not `StreakState`).

**Fix:** Add a `resetStreak(context:)` helper that fetches and resets the existing `StreakState`, then call it from both `deleteHistory` and `resetToOnboarding`:

```swift
private func resetStreak(context: ModelContext) {
    let descriptor = FetchDescriptor<StreakState>()
    guard let state = (try? context.fetch(descriptor))?.first else { return }
    state.currentStreak = 0
    state.longestStreak = 0
    state.lastActiveDate = nil
}
```

Property names on `StreakState` are `currentStreak`, `longestStreak`, `lastActiveDate` (not `lastTrainingDate`).

**Files:** `inch/inch/Features/Settings/SettingsViewModel.swift`

### 1.3 Confirmation Dialogs → Centered Alerts

**Problem:** `.confirmationDialog` renders as a bottom action sheet. On iPhone this looks disconnected from the triggering button and feels inconsistent for destructive actions.

**Fix:** Replace all `.confirmationDialog` with `.alert` across:
- `WorkoutSessionView` — quit workout confirmation
- `PrivacySettingsView` — delete history, reset app, unlink sensor data (3 dialogs)

Keep identical button roles (`.destructive`, `.cancel`) and message text.

Key differences between `.alert` and `.confirmationDialog` to handle:
- Drop the `titleVisibility: .visible` parameter — `.alert` always shows its title
- The unlink dialog button contains async work in a `Task {}` block — preserve this exactly

`PrivacySettingsView` will have four `.alert` modifiers total after this change (three converted + the existing `.alert("Couldn't Unlink Data", ...)`). This is valid in SwiftUI iOS 15+ — multiple `.alert` modifiers with separate `isPresented` bindings on the same view work correctly.

**Files:**
- `inch/inch/Features/Workout/WorkoutSessionView.swift`
- `inch/inch/Features/Settings/PrivacySettingsView.swift`

### 1.4 "Quit Workout" Back Button Label

**Problem:** `WorkoutSessionView` already hides the default back button and shows a custom leading toolbar button, but it is labelled "Back" with a `chevron.left` icon. The label gives no indication that tapping it quits the workout, and the chevron implies navigation rather than a destructive action.

**Fix:** Change the existing custom leading toolbar button to display only the text "Quit Workout" with no icon. Remove the `Image(systemName: "chevron.left")` from the button label.

**Files:** `inch/inch/Features/Workout/WorkoutSessionView.swift`

### 1.5 Partial Workout Marked as Complete

**Problem:** `TodayViewModel.loadToday` uses `Set(todaySets.map(\.exerciseId))` to build both `completedTodayIds` (which drives the checkmark on `ExerciseCard`) and `completedEnrolments` (which keeps completed exercises visible on the Today screen after they advance past their scheduled date). This marks an exercise complete if any set was recorded today, regardless of how many.

**Fix:** Build a `fullyCompletedIds` set — exercise IDs where the number of today's sets meets or exceeds the prescribed set count — and use it for both `completedTodayIds` and `completedEnrolments`:

```swift
// Group today's sets by exercise ID
let setsByExercise = Dictionary(grouping: todaySets, by: \.exerciseId)

// An exercise is fully complete when all prescribed sets are done
let fullyCompletedIds = Set(all.compactMap { enrolment -> String? in
    guard let id = enrolment.exerciseDefinition?.exerciseId else { return nil }
    let completedCount = setsByExercise[id]?.count ?? 0
    let prescribedCount = currentPrescription(for: enrolment)?.sets.count ?? 0
    guard prescribedCount > 0, completedCount >= prescribedCount else { return nil }
    return id
})

completedTodayIds = fullyCompletedIds

let completedEnrolments = all.filter { enrolment in
    guard let id = enrolment.exerciseDefinition?.exerciseId else { return false }
    return fullyCompletedIds.contains(id) && !dueToday.contains(where: { $0.persistentModelID == enrolment.persistentModelID })
}
```

`DayPrescription.sets` is `[Int]` (rep targets per set), so `.sets.count` is the number of prescribed sets.

**Completion rule:** All prescribed sets must be completed. Individual sets may exceed the prescribed rep count (doing more reps is acceptable).

**Files:** `inch/inch/Features/Today/TodayViewModel.swift`

### 1.6 Remove Contributor ID from UI

**Problem:** The Contributor ID section in `PrivacySettingsView` exposes an internal implementation detail that is irrelevant to users.

**Fix:** Delete the `contributorSection` private function and remove its call site (the `if let id = settings?.contributorId, !id.isEmpty` conditional block that calls it, located in `body`).

**Files:** `inch/inch/Features/Settings/PrivacySettingsView.swift`

---

## Section 2: Stats Charts Redesign

Replace `HistoryStatsView` content with three visual sections in a `ScrollView`. Each section uses a card-style background (`.background(.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: 12))`) consistent with the app's grouped list style.

`HistoryStatsView` receives `stats: HistoryViewModel.HistoryStats` and `streakState: StreakState?`. The existing `WeeklyVolumeChart` component is reused for the bar chart section.

### 2.1 Streak Panel

Large numeral display — no chart. Current streak and best streak displayed as large bold numbers with a flame SF Symbol (`flame.fill`) in orange.

Layout: Two side-by-side stat blocks in an `HStack`, each with a label above ("Current Streak", "Best Streak") and a large `.largeTitle`-weight number below.

Data source: `streakState?.currentStreak ?? 0` and `streakState?.longestStreak ?? 0`. Display "0" when `streakState` is nil (no training recorded yet).

### 2.2 Weekly Completion Ring

A donut chart (`SectorMark` in Swift Charts) showing days trained vs rest days in the last 7 days. Trained days filled in `.accentColor`, rest days in `.secondary.opacity(0.2)`. A text label centred inside the ring shows the fraction (e.g. "5/7"). The denominator is always 7.

**Data source:** Add `daysTrainedThisWeek: Int` to `HistoryViewModel.HistoryStats` and compute it in `HistoryViewModel.stats(from:enrolments:)`:

```swift
let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: today) ?? today
let daysTrainedThisWeek = Set(
    sets.filter { $0.sessionDate >= sevenDaysAgo }
        .map { calendar.startOfDay(for: $0.sessionDate) }
).count
```

Note: uses `?? today` fallback instead of force-unwrap, consistent with project style.

Pass `daysTrainedThisWeek` into the `HistoryStats` initialiser. `HistoryStats` is constructed only in `stats(from:enrolments:)`, so no other call sites exist.

### 2.3 Weekly Volume Bar Chart

Reuse the existing `WeeklyVolumeChart` component (already implemented in `WeeklyVolumeChart.swift`). Wire it into the redesigned `HistoryStatsView` as the third card section, passing `stats.weeklyData`.

### File Changes

- `inch/inch/Features/History/HistoryStatsView.swift` — full content replacement with three-section layout
- `inch/inch/Features/History/HistoryViewModel.swift` — add `daysTrainedThisWeek: Int` to `HistoryStats` struct and populate in `stats(from:enrolments:)`

---

## Section 3: watchOS Improvements

### 3.1 Today View Title

`WatchHistoryView` sets `.navigationTitle("History")` directly on its `List` — the same pattern works in `WatchTodayView`. Add `.navigationTitle("Today")` to the `List` in the `else` branch. No `NavigationStack` wrapper needed.

The `WatchRestDayView` branch does not need a title.

**Files:** `inch/inchwatch Watch App/Features/WatchTodayView.swift`

### 3.2 Exercise Icons in Today List

Map `exerciseId` to an SF Symbol name via a local function or dictionary. Display as `Image(systemName:)` next to each exercise name in the today list row.

**Mapping:**
- `push_ups` → `figure.push.ups`
- `squats` → `figure.squats`
- `sit_ups` → `figure.sit.ups`
- `pull_ups` → `figure.pull.ups`
- `glute_bridges` → `figure.flexibility`
- `dead_bugs` → `figure.core.training`

Fallback for unknown exercise IDs: `figure.strengthtraining.functional`.

Row layout: replace the current `VStack`-only button label with an `HStack(alignment: .center, spacing: 8)` — SF Symbol icon (`.font(.title3)`) on the leading side, then the existing `VStack` of exercise name and subtitle.

**Files:** `inch/inchwatch Watch App/Features/WatchTodayView.swift`

### 3.3 Watch Layout Fixes

Targeted fixes per view:

**WatchReadyView** — Current layout has two `Spacer(minLength: 4)` elements and a 40pt rep count in its own line that creates unbalanced distribution (content pushed to extremes). Fix:
- Remove both `Spacer(minLength: 4)` elements
- Reduce `repsFontSize` from 40 to 28pt
- Combine the rep count and "reps" text into a single `HStack(alignment: .firstTextBaseline, spacing: 4)` (e.g. "12 reps"), replacing the two separate `Text` lines
- Change `VStack(spacing: 6)` to `VStack(spacing: 8)` so the tighter content has slightly more breathing room
- Increase exercise name font from `.caption2` to `.footnote`

**WatchInSetView** — The HR badge is applied via `.overlay(alignment: .topTrailing)` on the containing view, causing it to overlap the timer. Fix:
- Remove the `.overlay` for `WatchHRBadge` from `WatchInSetView`
- Place `WatchHRBadge` as the first element at the top of the main `VStack`, above the timer/elapsed content, so it stacks vertically rather than overlapping

**WatchRestTimerView** — The `VStack` does not fill the screen height, causing content to cluster near the top. Fix:
- Add `.frame(maxWidth: .infinity, maxHeight: .infinity)` to the `VStack` so it fills the available space and centres content vertically within the watch face

**WatchExerciseCompleteView** — The `ScrollView > VStack` layout works but appears top-heavy when content is short. Fix:
- Add `.frame(maxWidth: .infinity, minHeight: 160)` to the inner `VStack` so it has minimum height to centre naturally within the scroll view

**Files:**
- `inch/inchwatch Watch App/Features/WatchReadyView.swift`
- `inch/inchwatch Watch App/Features/WatchInSetView.swift`
- `inch/inchwatch Watch App/Features/WatchRestTimerView.swift`
- `inch/inchwatch Watch App/Features/WatchExerciseCompleteView.swift`

### 3.4 Completed Exercise Persists After Workout

**Problem:** After finishing a workout on the watch, the completed session remains visible in the Today list until the iPhone pushes a new schedule. `WatchConnectivityService` persists sessions to `UserDefaults` via `store(_:)` — without updating UserDefaults, the stale session is restored on next app launch.

**Fix:** Add `func removeSession(exerciseId: String)` to `WatchConnectivityService`:

```swift
func removeSession(exerciseId: String) {
    sessions.removeAll { $0.exerciseId == exerciseId }
    store(sessions)
}
```

In `WatchWorkoutView`'s `.complete` phase handler, call `watchConnectivity.removeSession(exerciseId: session.exerciseId)` **before** `dismiss()`, inside the existing `Task {}` block. This covers both the "Done" path and the "start next exercise" path, since the call happens before the `if let nextSession` branch:

```swift
Task {
    historyStore.record(report, exerciseName: session.exerciseName)
    watchConnectivity.sendCompletionReport(report)
    await healthService.endWorkout()
    watchConnectivity.removeSession(exerciseId: session.exerciseId) // remove before dismiss
    if let nextSession {
        onStartNext?(nextSession)
    }
    dismiss()
}
```

Note: this fix is best-effort. If the phone sends a `WCSession` application context update before the user relaunches the watch app, it will replace the full sessions list from the phone's authoritative state anyway. The fix eliminates the common case where the session stays visible until the next phone push.

**Files:**
- `inch/inchwatch Watch App/Services/WatchConnectivityService.swift`
- `inch/inchwatch Watch App/Features/WatchWorkoutView.swift`
