# v1 Polish — Bugs & Improvements Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all bugs identified in user testing and improve visual polish across iOS and watchOS.

**Architecture:** Isolated fixes to existing view and view model files across three areas: iOS bug fixes (appearance picker, streak, dialogs, quit button, completion logic, contributor ID), stats charts redesign (HistoryViewModel data + HistoryStatsView layout), and watchOS improvements (title, icons, layout, session persistence).

**Tech Stack:** SwiftUI, Swift Charts, SF Symbols, SwiftData, Swift Testing

---

## File Map

**Modified — iOS:**
- `inch/inch/Features/Settings/SettingsView.swift` — extract `AppearanceSectionView`
- `inch/inch/Features/Settings/SettingsViewModel.swift` — add `resetStreak` helper
- `inch/inch/Features/Workout/WorkoutSessionView.swift` — rename button, swap dialog to alert
- `inch/inch/Features/Settings/PrivacySettingsView.swift` — swap 3 dialogs to alerts, remove contributor section
- `inch/inch/Features/Today/TodayViewModel.swift` — tighten completion logic

**Modified — Stats:**
- `inch/inch/Features/History/HistoryViewModel.swift` — add `daysTrainedThisWeek` to `HistoryStats`
- `inch/inch/Features/History/HistoryStatsView.swift` — full content replacement with 3-section layout

**Modified — watchOS:**
- `inch/inchwatch Watch App/Features/WatchTodayView.swift` — add title, add exercise icons
- `inch/inchwatch Watch App/Features/WatchReadyView.swift` — layout fix
- `inch/inchwatch Watch App/Features/WatchInSetView.swift` — HR badge fix
- `inch/inchwatch Watch App/Features/WatchRestTimerView.swift` — centring fix
- `inch/inchwatch Watch App/Features/WatchExerciseCompleteView.swift` — centring fix
- `inch/inchwatch Watch App/Services/WatchConnectivityService.swift` — add `removeSession`
- `inch/inchwatch Watch App/Features/WatchWorkoutView.swift` — call `removeSession` on complete

---

## Chunk 1: iOS Bug Fixes

### Task 1: Fix Appearance Picker Stale State

**Files:**
- Modify: `inch/inch/Features/Settings/SettingsView.swift`

**Context:** The current `appearanceSection` computed property constructs a manual `Binding(get:set:)` inside an `if let settings = viewModel.settings` check. When settings changes identity rapidly, the picker re-creates and the second selection doesn't propagate. The fix is to extract a private subview that uses `@Bindable`.

- [ ] **Open `inch/inch/Features/Settings/SettingsView.swift`**

The current `appearanceSection` is a computed property on `SettingsView`. The `Picker` inside uses a manual `Binding(get:set:)` that calls `try? modelContext.save()`. The view also has a `workoutSection`, `privacySection` — the appearance section is called in `body` as part of the `List`.

- [ ] **Replace `appearanceSection` with `AppearanceSectionView` private struct**

Delete the `private var appearanceSection: some View` computed property entirely. Add the following as a **file-scope** `private struct` after the closing brace of `SettingsView` (not nested inside it):

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

- [ ] **Update the call site in `SettingsView.body`**

The `List` in `body` currently calls `appearanceSection` as the first item. Replace it:

```swift
// Before
List {
    appearanceSection
    workoutSection
    ...
}

// After
List {
    if let s = viewModel.settings {
        AppearanceSectionView(settings: s)
    }
    workoutSection
    ...
}
```

Note: when `viewModel.settings` is `nil` (briefly on first render before SwiftData loads), the Appearance section will be absent from the list. This is intentional and consistent with how the rest of `SettingsView` handles nil settings (e.g. `NotificationsSettingsSection` and `ScheduleSettingsSection` are also wrapped in `if let settings`). The settings object loads very quickly from the local store so the flash is imperceptible.

- [ ] **Build and verify**

Build the `inch` scheme. Open Settings → rapidly tap System → Light → Dark → System. Each tap should immediately update the app appearance behind the settings sheet.

- [ ] **Commit**

```bash
git add inch/inch/Features/Settings/SettingsView.swift
git commit -m "fix: resolve stale appearance picker with @Bindable subview"
```

---

### Task 2: Reset Streak When Deleting History or Resetting App

**Files:**
- Modify: `inch/inch/Features/Settings/SettingsViewModel.swift`

**Context:** `deleteHistory` deletes `CompletedSet` records but leaves `StreakState` untouched. `resetToOnboarding` deletes `CompletedSet`, `ExerciseEnrolment`, and `UserSettings` but also leaves `StreakState`. Both need to reset streak to zero. `StreakState` is in `InchShared` — ensure `import InchShared` is present in `SettingsViewModel.swift`.

- [ ] **Open `inch/inch/Features/Settings/SettingsViewModel.swift`**

Locate `deleteHistory(context:)` and `resetToOnboarding(context:)`.

- [ ] **Add `resetStreak` helper and call it from both functions**

Add a private helper below the existing functions:

```swift
private func resetStreak(context: ModelContext) {
    let descriptor = FetchDescriptor<StreakState>()
    guard let state = (try? context.fetch(descriptor))?.first else { return }
    state.currentStreak = 0
    state.longestStreak = 0
    state.lastActiveDate = nil
}
```

Then call it from both:

```swift
func deleteHistory(context: ModelContext) {
    try? context.delete(model: CompletedSet.self)
    resetStreak(context: context)
    try? context.save()
}

func resetToOnboarding(context: ModelContext) {
    try? context.delete(model: CompletedSet.self)
    try? context.delete(model: ExerciseEnrolment.self)
    try? context.delete(model: UserSettings.self)
    resetStreak(context: context)
    try? context.save()
}
```

Note: `StreakState` property names are `currentStreak`, `longestStreak`, `lastActiveDate`.

- [ ] **Build and verify**

Build `inch`. Navigate to Settings → Data & Privacy → Delete Workout History → confirm. Go to History → Stats. Streak should show 0 / 0.

- [ ] **Commit**

```bash
git add inch/inch/Features/Settings/SettingsViewModel.swift
git commit -m "fix: reset streak state when deleting history or resetting app"
```

---

### Task 3: Quit Workout Button + Dialog → Alert

**Files:**
- Modify: `inch/inch/Features/Workout/WorkoutSessionView.swift`

**Context:** Two changes in this file: (1) rename the toolbar button from "Back" (with chevron) to "Quit Workout" (text only); (2) convert the `.confirmationDialog` at the bottom of `body` to `.alert`.

- [ ] **Open `inch/inch/Features/Workout/WorkoutSessionView.swift`**

Find the `.toolbar` block (around line 73–86). The leading button currently renders:
```swift
HStack(spacing: 4) {
    Image(systemName: "chevron.left")
    Text("Back")
}
```

- [ ] **Update the button label**

Replace the `HStack` label with just `Text("Quit Workout")`:

```swift
ToolbarItem(placement: .topBarLeading) {
    Button {
        showingQuitConfirm = true
    } label: {
        Text("Quit Workout")
    }
}
```

- [ ] **Convert the confirmation dialog to an alert**

Find the `.confirmationDialog(...)` modifier (around line 87–96). Replace it with `.alert`:

```swift
// Before
.confirmationDialog(
    "Quit workout?",
    isPresented: $showingQuitConfirm,
    titleVisibility: .visible
) {
    Button("Quit Workout", role: .destructive) { dismiss() }
    Button("Cancel", role: .cancel) {}
} message: {
    Text("Your progress so far won't be saved.")
}

// After
.alert(
    "Quit workout?",
    isPresented: $showingQuitConfirm
) {
    Button("Quit Workout", role: .destructive) { dismiss() }
    Button("Cancel", role: .cancel) {}
} message: {
    Text("Your progress so far won't be saved.")
}
```

- [ ] **Build and verify**

Build `inch`. Start a workout. The back button should now read "Quit Workout" with no chevron. Tapping it should show a centred alert card (not a bottom sheet).

- [ ] **Commit**

```bash
git add inch/inch/Features/Workout/WorkoutSessionView.swift
git commit -m "fix: rename quit button and convert quit dialog to centered alert"
```

---

### Task 4: Privacy Settings — Alerts + Remove Contributor Section

**Files:**
- Modify: `inch/inch/Features/Settings/PrivacySettingsView.swift`

**Context:** Three `.confirmationDialog` modifiers to convert to `.alert`. Also remove the `contributorSection` function and its call site. The unlink dialog has async work in a `Task {}` block — preserve it exactly. After conversion there will be four `.alert` modifiers (three converted + the existing `showingUnlinkError` alert) — this is valid in SwiftUI iOS 15+ with separate `isPresented` bindings.

- [ ] **Open `inch/inch/Features/Settings/PrivacySettingsView.swift`**

There are three `.confirmationDialog` modifiers on `body`: delete history, reset app, and unlink sensor data.

- [ ] **Convert delete history dialog**

```swift
// Before
.confirmationDialog(
    "Delete all workout history?",
    isPresented: $showingDeleteHistoryConfirm,
    titleVisibility: .visible
) {
    Button("Delete History", role: .destructive) {
        viewModel.deleteHistory(context: modelContext)
    }
    Button("Cancel", role: .cancel) {}
} message: {
    Text("All completed sets and session records will be permanently deleted. Your programme progress is kept.")
}

// After
.alert(
    "Delete all workout history?",
    isPresented: $showingDeleteHistoryConfirm
) {
    Button("Delete History", role: .destructive) {
        viewModel.deleteHistory(context: modelContext)
    }
    Button("Cancel", role: .cancel) {}
} message: {
    Text("All completed sets and session records will be permanently deleted. Your programme progress is kept.")
}
```

- [ ] **Convert reset app dialog**

```swift
// Before
.confirmationDialog(
    "Reset app to onboarding?",
    isPresented: $showingResetConfirm,
    titleVisibility: .visible
) {
    Button("Reset Everything", role: .destructive) {
        viewModel.resetToOnboarding(context: modelContext)
    }
    Button("Cancel", role: .cancel) {}
} message: {
    Text("All progress, history, and settings will be permanently deleted. You'll go through onboarding again.")
}

// After
.alert(
    "Reset app to onboarding?",
    isPresented: $showingResetConfirm
) {
    Button("Reset Everything", role: .destructive) {
        viewModel.resetToOnboarding(context: modelContext)
    }
    Button("Cancel", role: .cancel) {}
} message: {
    Text("All progress, history, and settings will be permanently deleted. You'll go through onboarding again.")
}
```

- [ ] **Convert unlink sensor data dialog (preserve async Task)**

```swift
// Before
.confirmationDialog(
    "Unlink sensor data?",
    isPresented: $showingUnlinkConfirm,
    titleVisibility: .visible
) {
    Button("Unlink My Data", role: .destructive) {
        guard let id = settings?.contributorId, !id.isEmpty else { return }
        isUnlinking = true
        Task {
            do {
                try await dataUpload.unlinkContributorData(contributorId: id)
                settings?.contributorId = UUID().uuidString.lowercased()
                try? modelContext.save()
            } catch {
                showingUnlinkError = true
            }
            isUnlinking = false
        }
    }
    Button("Cancel", role: .cancel) {}
} message: {
    Text("Your sensor recordings will remain on the server but can no longer be linked to this device. Future uploads will use a new anonymous ID.")
}

// After
.alert(
    "Unlink sensor data?",
    isPresented: $showingUnlinkConfirm
) {
    Button("Unlink My Data", role: .destructive) {
        guard let id = settings?.contributorId, !id.isEmpty else { return }
        isUnlinking = true
        Task {
            do {
                try await dataUpload.unlinkContributorData(contributorId: id)
                settings?.contributorId = UUID().uuidString.lowercased()
                try? modelContext.save()
            } catch {
                showingUnlinkError = true
            }
            isUnlinking = false
        }
    }
    Button("Cancel", role: .cancel) {}
} message: {
    Text("Your sensor recordings will remain on the server but can no longer be linked to this device. Future uploads will use a new anonymous ID.")
}
```

- [ ] **Remove `contributorSection` and its call site**

Delete the entire `private var contributorSection: some View` computed property (the `Section("Contributor")` block at the bottom of the file).

Find its call site in `body` (inside the `List`) and delete that line too. The `List` currently calls `contributorSection` — remove it.

- [ ] **Build and verify**

Build `inch`. Open Settings → Data & Privacy. Tap "Delete Workout History" — a centred card alert should appear. The Contributor ID section should be gone.

- [ ] **Commit**

```bash
git add inch/inch/Features/Settings/PrivacySettingsView.swift
git commit -m "fix: convert privacy dialogs to centered alerts, remove contributor ID section"
```

---

### Task 5: Fix Partial Workout Marked as Complete

**Files:**
- Modify: `inch/inch/Features/Today/TodayViewModel.swift`

**Context:** `loadToday` currently uses `Set(todaySets.map(\.exerciseId))` for both `completedTodayIds` and `completedEnrolments`. This marks any exercise with even one set today as complete. The fix: build `fullyCompletedIds` — exercise IDs where today's set count meets the prescribed set count — and use it for both.

`DayPrescription.sets` is `[Int]` (array of rep targets per set), so `.sets.count` is the number of prescribed sets. `currentPrescription(for:)` already exists on `TodayViewModel` and returns `DayPrescription?`.

- [ ] **Open `inch/inch/Features/Today/TodayViewModel.swift`**

Find lines 33–43 (the `completedIds` and `completedEnrolments` logic):

```swift
let todaySets = (try? context.fetch(setsDescriptor)) ?? []
let completedIds = Set(todaySets.map(\.exerciseId))
completedTodayIds = completedIds

let completedEnrolments = all.filter { enrolment in
    guard let id = enrolment.exerciseDefinition?.exerciseId else { return false }
    return completedIds.contains(id) && !dueToday.contains(where: { $0.persistentModelID == enrolment.persistentModelID })
}
```

- [ ] **Replace with `fullyCompletedIds` logic**

```swift
let todaySets = (try? context.fetch(setsDescriptor)) ?? []

// Group today's sets by exercise ID
let setsByExercise = Dictionary(grouping: todaySets, by: \.exerciseId)

// An exercise is fully complete when today's set count >= prescribed set count
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

- [ ] **Build and verify**

Build `inch`. Start a workout and complete only 1 set (less than prescribed), then quit. The exercise card on Today should NOT show as completed. Complete all sets — it should show as completed.

- [ ] **Commit**

```bash
git add inch/inch/Features/Today/TodayViewModel.swift
git commit -m "fix: only mark exercise complete when all prescribed sets are done"
```

---

## Chunk 2: Stats Charts Redesign

### Task 6: Add `daysTrainedThisWeek` to HistoryViewModel

**Files:**
- Modify: `inch/inch/Features/History/HistoryViewModel.swift`

**Context:** `HistoryStats` is a plain struct with `let` properties. Add `daysTrainedThisWeek: Int`. The only construction site is `stats(from:enrolments:)` in this file. The computation counts distinct calendar days in the last 7 days (today inclusive = days -6 through 0) that appear in the `sets` array.

- [ ] **Open `inch/inch/Features/History/HistoryViewModel.swift`**

Find the `HistoryStats` struct (around line 157):

```swift
struct HistoryStats {
    let totalReps: Int
    let sessionCount: Int
    let exerciseStats: [ExerciseStat]
    let weeklyData: [WeeklyData]
}
```

- [ ] **Add `daysTrainedThisWeek` property**

```swift
struct HistoryStats {
    let totalReps: Int
    let sessionCount: Int
    let daysTrainedThisWeek: Int
    let exerciseStats: [ExerciseStat]
    let weeklyData: [WeeklyData]
}
```

- [ ] **Compute `daysTrainedThisWeek` in `stats(from:enrolments:)`**

Find `stats(from:enrolments:)`. Before the `return HistoryStats(...)` call, add:

```swift
let today = calendar.startOfDay(for: .now)
let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: today) ?? today
let daysTrainedThisWeek = Set(
    sets.filter { $0.sessionDate >= sevenDaysAgo }
        .map { calendar.startOfDay(for: $0.sessionDate) }
).count
```

Note: `calendar` is already declared at the top of `stats(from:enrolments:)` as `let calendar = Calendar.current`.

- [ ] **Pass `daysTrainedThisWeek` into the `HistoryStats` initialiser**

```swift
return HistoryStats(
    totalReps: totalReps,
    sessionCount: sessionCount,
    daysTrainedThisWeek: daysTrainedThisWeek,
    exerciseStats: exerciseStats,
    weeklyData: weeklyData(from: sets)
)
```

- [ ] **Build and verify compile**

Run: `xcodebuild build -scheme inch -destination 'generic/platform=iOS Simulator' 2>&1 | grep -E "error:|Build succeeded"`

Expected: `Build succeeded`

- [ ] **Commit**

```bash
git add inch/inch/Features/History/HistoryViewModel.swift
git commit -m "feat: add daysTrainedThisWeek to HistoryStats"
```

---

### Task 7: Redesign HistoryStatsView with Three Chart Sections

**Files:**
- Modify: `inch/inch/Features/History/HistoryStatsView.swift`

**Context:** Full content replacement. Three card sections in a `ScrollView`:
1. **Streak panel** — side-by-side large numerals with flame icon
2. **Weekly completion ring** — `SectorMark` donut showing days trained / 7
3. **Weekly volume bar chart** — reuse existing `WeeklyVolumeChart` component

The view signature stays the same: `let stats: HistoryViewModel.HistoryStats` and `let streakState: StreakState?`. The existing `StatCard`, `ExerciseStatRow` private structs are no longer needed. Keep `ExerciseStatRow` and the exercise stats list as a fourth section at the bottom (it shows useful per-exercise data).

- [ ] **Open `inch/inch/Features/History/HistoryStatsView.swift`**

- [ ] **Replace the entire file content**

```swift
import SwiftUI
import Charts
import InchShared

struct HistoryStatsView: View {
    let stats: HistoryViewModel.HistoryStats
    let streakState: StreakState?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                streakCard
                completionRingCard
                if !stats.weeklyData.isEmpty {
                    volumeChartCard
                }
                if !stats.exerciseStats.isEmpty {
                    exerciseStatsCard
                }
            }
            .padding()
        }
    }

    // MARK: - Streak Panel

    private var streakCard: some View {
        HStack(spacing: 0) {
            streakBlock(
                value: streakState?.currentStreak ?? 0,
                label: "Current Streak",
                isLeading: true
            )
            Divider().frame(height: 60)
            streakBlock(
                value: streakState?.longestStreak ?? 0,
                label: "Best Streak",
                isLeading: false
            )
        }
        .padding(.vertical, 16)
        .background(.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: 12))
    }

    private func streakBlock(value: Int, label: String, isLeading: Bool) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text("\(value)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
    }

    // MARK: - Weekly Completion Ring

    private var completionRingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.headline)

            HStack(spacing: 24) {
                ZStack {
                    Chart {
                        let trained = stats.daysTrainedThisWeek
                        let rest = max(0, 7 - trained)
                        SectorMark(angle: .value("Trained", trained), innerRadius: .ratio(0.6))
                            .foregroundStyle(Color.accentColor)
                        SectorMark(angle: .value("Rest", rest), innerRadius: .ratio(0.6))
                            .foregroundStyle(Color.secondary.opacity(0.2))
                    }
                    .frame(width: 100, height: 100)

                    Text("\(stats.daysTrainedThisWeek)/7")
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                VStack(alignment: .leading, spacing: 8) {
                    legendRow(color: .accentColor, label: "Training days", value: "\(stats.daysTrainedThisWeek)")
                    legendRow(color: .secondary.opacity(0.4), label: "Rest days", value: "\(max(0, 7 - stats.daysTrainedThisWeek))")
                }

                Spacer()
            }
        }
        .padding(16)
        .background(.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: 12))
    }

    private func legendRow(color: Color, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }

    // MARK: - Weekly Volume Chart

    private var volumeChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Volume")
                .font(.headline)
            WeeklyVolumeChart(weeklyData: stats.weeklyData)
        }
        .padding(16)
        .background(.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Exercise Stats

    private var exerciseStatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Exercise")
                .font(.headline)
                .padding(.horizontal, 4)
            VStack(spacing: 0) {
                ForEach(stats.exerciseStats) { exercise in
                    ExerciseStatRow(stat: exercise)
                    if exercise.id != stats.exerciseStats.last?.id {
                        Divider()
                            .padding(.leading, 44)
                    }
                }
            }
            .background(.background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(16)
        .background(.secondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - ExerciseStatRow (unchanged from previous)

private struct ExerciseStatRow: View {
    let stat: HistoryViewModel.ExerciseStat
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: stat.color) ?? .accentColor)
                .frame(width: 10, height: 10)
                .padding(.leading, 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(stat.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("L\(stat.currentLevel) · Day \(stat.currentDay) of \(stat.totalDaysInLevel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(stat.totalReps.formatted()) reps")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.trailing, 12)
        }
        .padding(.vertical, 10)
    }
}
```

Note: `Color(hex:)` is used by the existing `ExerciseStatRow` — it must already exist as an extension in the project. Do not add it; it's already there.

- [ ] **Build and verify**

Build `inch`. Navigate to History → Stats tab. You should see:
- A streak card with flame icons and large numbers
- A completion ring showing this week's training days out of 7
- A weekly volume bar chart (if history exists)
- Per-exercise stats at the bottom

- [ ] **Commit**

```bash
git add inch/inch/Features/History/HistoryStatsView.swift
git commit -m "feat: redesign stats view with streak panel, completion ring, and volume chart"
```

---

## Chunk 3: watchOS Improvements

### Task 8: Watch Today View — Title and Exercise Icons

**Files:**
- Modify: `inch/inchwatch Watch App/Features/WatchTodayView.swift`

**Context:** Add `.navigationTitle("Today")` to the `List`. `WatchHistoryView` uses this same pattern without a `NavigationStack` wrapper — the `TabView` in `inchwatchApp` provides the navigation container. Add SF Symbol icons to each exercise row using an `exerciseIcon(for:)` helper.

- [ ] **Open `inch/inchwatch Watch App/Features/WatchTodayView.swift`**

The current `List` button label is a plain `VStack` with exercise name and subtitle.

- [ ] **Add `exerciseIcon` helper and update list row layout**

Replace `body` and add the helper:

```swift
var body: some View {
    if watchConnectivity.sessions.isEmpty {
        WatchRestDayView(lastSyncDate: watchConnectivity.lastSyncDate)
    } else {
        List(watchConnectivity.sessions) { session in
            Button {
                activeSession = session
            } label: {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: exerciseIcon(for: session.exerciseId))
                        .font(.title3)
                        .foregroundStyle(.accentColor)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.exerciseName)
                            .font(.headline)
                        Text("Level \(session.level) · Day \(session.dayNumber)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if session.isTest {
                            Text("TEST DAY")
                                .font(.caption2)
                                .bold()
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
        .navigationTitle("Today")
        .sheet(item: $activeSession) { session in
            WatchWorkoutView(session: session, settings: settings) { next in
                pendingNextSession = next
                activeSession = nil
            }
        }
        .onChange(of: activeSession) { _, newValue in
            guard newValue == nil, let next = pendingNextSession else { return }
            pendingNextSession = nil
            activeSession = next
        }
    }
}

private func exerciseIcon(for exerciseId: String) -> String {
    switch exerciseId {
    case "push_ups":      return "figure.strengthtraining.traditional"
    case "squats":        return "figure.strengthtraining.functional"
    case "sit_ups":       return "figure.core.training"
    case "pull_ups":      return "figure.gymnastics"
    case "glute_bridges": return "figure.flexibility"
    case "dead_bugs":     return "figure.cooldown"
    default:              return "figure.strengthtraining.functional"
    }
}
```

**Important:** Before shipping, verify each SF Symbol name is available on watchOS 11 by opening the SF Symbols app (version 6), searching each name, and checking the availability badge. Invalid names render as a blank/question-mark at runtime with no build error. The names above use confirmed-common symbols but the per-exercise mapping may be improved once verified.

- [ ] **Build the watch scheme and verify**

Build the `inchwatch Watch App` scheme targeting Apple Watch Series 10 simulator. The Today tab should show "Today" as the navigation title and each exercise row should have a coloured SF Symbol icon on the left.

- [ ] **Commit**

```bash
git add "inch/inchwatch Watch App/Features/WatchTodayView.swift"
git commit -m "feat: add Today title and exercise icons to watch Today view"
```

---

### Task 9: Watch Layout Fixes (4 Views)

**Files:**
- Modify: `inch/inchwatch Watch App/Features/WatchReadyView.swift`
- Modify: `inch/inchwatch Watch App/Features/WatchInSetView.swift`
- Modify: `inch/inchwatch Watch App/Features/WatchRestTimerView.swift`
- Modify: `inch/inchwatch Watch App/Features/WatchExerciseCompleteView.swift`

**Context:** All four views have layout balance issues. Fixes are targeted per view.

#### WatchReadyView

Current layout has two `Spacer(minLength: 4)` and a large 40pt rep count creating unbalanced distribution. Fix: remove Spacers, reduce font, combine rep count + label on one line.

- [ ] **Replace `body` in `WatchReadyView.swift`**

```swift
var body: some View {
    VStack(spacing: 8) {
        Text(session.exerciseName)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        Text("Set \(viewModel.currentSet) of \(viewModel.totalSets)")
            .font(.caption)
            .foregroundStyle(.secondary)
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(viewModel.targetReps)")
                .font(.system(size: repsFontSize, weight: .bold, design: .rounded))
            Text("reps")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Button("Start") {
            if viewModel.completedSets.isEmpty {
                Task { await healthService.startWorkout() }
            }
            viewModel.startSet()
        }
        .buttonStyle(.borderedProminent)
        .frame(maxWidth: .infinity)
    }
    .padding(.horizontal)
    .padding(.top, 8)
}
```

Also change `@ScaledMetric private var repsFontSize: CGFloat = 40` to `@ScaledMetric private var repsFontSize: CGFloat = 28`.

#### WatchInSetView

The HR badge is applied via `.overlay(alignment: .topTrailing)` causing overlap with the timer. Fix: remove overlay, place `WatchHRBadge` at top of VStack.

- [ ] **Replace `body` in `WatchInSetView.swift`**

```swift
var body: some View {
    VStack(spacing: 6) {
        WatchHRBadge(showHeartRate: showHeartRate, currentBPM: currentBPM)
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
            .font(.system(size: elapsedFontSize, weight: .semibold, design: .monospaced))
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
    .task {
        while true {
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return
            }
            elapsed = Int(Date.now.timeIntervalSince(setStartDate))
        }
    }
}
```

#### WatchRestTimerView

VStack doesn't fill screen height, causing content to cluster near the top. Fix: add `frame(maxWidth: .infinity, maxHeight: .infinity)`.

- [ ] **Add frame modifier to the VStack in `WatchRestTimerView.swift`**

Change:
```swift
VStack(spacing: 8) {
    ...
}
.navigationTitle("Rest")
.navigationBarTitleDisplayMode(.inline)
```

To:
```swift
VStack(spacing: 8) {
    ...
}
.frame(maxWidth: .infinity, maxHeight: .infinity)
.navigationTitle("Rest")
.navigationBarTitleDisplayMode(.inline)
```

The `.navigationBarTitleDisplayMode(.inline)` line must be preserved — it is already in the file and keeps the title compact.

#### WatchExerciseCompleteView

Inner VStack appears top-heavy when content is short. Fix: add minimum height to inner VStack.

- [ ] **Add `minHeight` to the inner VStack in `WatchExerciseCompleteView.swift`**

Change:
```swift
ScrollView {
    VStack(spacing: 8) {
        ...
    }
    .padding(.vertical)
}
```

To:
```swift
ScrollView {
    VStack(spacing: 8) {
        ...
    }
    .frame(maxWidth: .infinity, minHeight: 160)
    .padding(.vertical)
}
```

- [ ] **Build and verify all four views in simulator**

Build the watch scheme. Run through a workout on the Apple Watch Series 10 simulator:
- Ready screen: rep count and "reps" on the same line, no extreme top-spacing
- In-set screen: HR badge at top, not overlapping the timer
- Rest screen: content centred vertically
- Complete screen: content centred, not top-heavy

- [ ] **Commit**

```bash
git add "inch/inchwatch Watch App/Features/WatchReadyView.swift"
git add "inch/inchwatch Watch App/Features/WatchInSetView.swift"
git add "inch/inchwatch Watch App/Features/WatchRestTimerView.swift"
git add "inch/inchwatch Watch App/Features/WatchExerciseCompleteView.swift"
git commit -m "fix: improve layout balance across all four watch workout views"
```

---

### Task 10: Watch Completed Exercise Persists — removeSession Fix

**Files:**
- Modify: `inch/inchwatch Watch App/Services/WatchConnectivityService.swift`
- Modify: `inch/inchwatch Watch App/Features/WatchWorkoutView.swift`

**Context:** After completing a workout, the session stays visible in the Today list until the iPhone sends a fresh schedule. Fix: add `removeSession(exerciseId:)` to `WatchConnectivityService` that removes from the in-memory array and updates `UserDefaults`. Call it in `WatchWorkoutView` before `dismiss()`.

- [ ] **Add `removeSession` to `WatchConnectivityService.swift`**

Open `inch/inchwatch Watch App/Services/WatchConnectivityService.swift`. Find the `store(_:)` private function. Add `removeSession` as a new `func` on the service:

```swift
func removeSession(exerciseId: String) {
    sessions.removeAll { $0.exerciseId == exerciseId }
    store(sessions)
}
```

Place it near the other public-facing methods (after `sendCompletionReport` or equivalent).

- [ ] **Call `removeSession` in `WatchWorkoutView.swift`**

Open `inch/inchwatch Watch App/Features/WatchWorkoutView.swift`. Find the `.complete` phase handler in the `onChange(of: viewModel.phase)` block — or in the `WatchExerciseCompleteView` `onDone` closure. The existing `Task` block looks like:

```swift
Task {
    historyStore.record(report, exerciseName: session.exerciseName)
    watchConnectivity.sendCompletionReport(report)
    await healthService.endWorkout()
    if let nextSession {
        onStartNext?(nextSession)
    }
    dismiss()
}
```

Add `removeSession` call before the `if let nextSession` branch:

```swift
Task {
    historyStore.record(report, exerciseName: session.exerciseName)
    watchConnectivity.sendCompletionReport(report)
    await healthService.endWorkout()
    watchConnectivity.removeSession(exerciseId: session.exerciseId)
    if let nextSession {
        onStartNext?(nextSession)
    }
    dismiss()
}
```

- [ ] **Build and verify**

Build the watch scheme. Complete a workout. The completed exercise should immediately disappear from the Today list when the completion sheet dismisses, without waiting for the iPhone to push a new schedule.

- [ ] **Commit**

```bash
git add "inch/inchwatch Watch App/Services/WatchConnectivityService.swift"
git add "inch/inchwatch Watch App/Features/WatchWorkoutView.swift"
git commit -m "fix: optimistically remove completed exercise from watch Today list"
```
