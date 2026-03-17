# Notifications & Settings v1.1 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement local notifications (daily reminders, streak protection, test day, level unlock, schedule adjustment) and wire the Settings UI notification section with toggles and time pickers.

**Architecture:** A new `NotificationService` (`@Observable`) is registered as an environment object in `InchApp`. It handles all UNUserNotificationCenter interactions. `WorkoutSessionView` calls it on workout completion to request permission (unconditionally — UNUserNotificationCenter is idempotent) and refresh the schedule. Settings gains a Notifications section backed by `UserSettings` fields. New section views are extracted into separate files per project conventions.

**Tech Stack:** UserNotifications framework, SwiftUI, SwiftData, `@Observable`

---

## Chunk 1: UserSettings + NotificationService

### Task 1: Add missing UserSettings fields

`UserSettings` already has daily reminder fields. Three fields are missing: streak protection time and the show-conflict-warnings toggle.

**Files:**
- Modify: `Shared/Sources/InchShared/Models/UserSettings.swift`

- [ ] **Add the three missing properties** to `UserSettings` after `levelUnlockNotificationEnabled`:

```swift
public var streakProtectionHour: Int = 19
public var streakProtectionMinute: Int = 0
public var showConflictWarnings: Bool = true
```

- [ ] **Add to `init` parameters** after `levelUnlockNotificationEnabled: Bool = true`:

```swift
streakProtectionHour: Int = 19,
streakProtectionMinute: Int = 0,
showConflictWarnings: Bool = true,
```

- [ ] **Assign in init body:**

```swift
self.streakProtectionHour = streakProtectionHour
self.streakProtectionMinute = streakProtectionMinute
self.showConflictWarnings = showConflictWarnings
```

- [ ] **Build to verify no errors**

- [ ] **Commit:**
```bash
git add Shared/Sources/InchShared/Models/UserSettings.swift
git commit -m "feat: add streakProtectionHour/Minute and showConflictWarnings to UserSettings"
```

---

### Task 2: Make SchedulingEngine.interLevelGapDays public

The notification service needs to know the inter-level gap to pass to `postLevelUnlock`. The constant is currently internal.

**Files:**
- Modify: `Shared/Sources/InchShared/Engine/SchedulingEngine.swift`

- [ ] **Change line 5** from `static let interLevelGapDays = 2` to:
```swift
public static let interLevelGapDays = 2
```

- [ ] **Commit:**
```bash
git add Shared/Sources/InchShared/Engine/SchedulingEngine.swift
git commit -m "feat: make SchedulingEngine.interLevelGapDays public"
```

---

### Task 3: Create NotificationService

**Files:**
- Create: `inch/inch/Services/NotificationService.swift`

The service is `@Observable`, implicitly `@MainActor` (app target default). All UNUserNotificationCenter calls are non-isolated on iOS 18 so they work fine from the main actor.

- [ ] **Create the file:**

```swift
import Foundation
import UserNotifications
import SwiftData
import InchShared

@Observable
final class NotificationService {
    var isAuthorized: Bool = false

    // MARK: - Permission

    /// Requests permission if not yet determined. Safe to call on every workout —
    /// UNUserNotificationCenter shows the system prompt only once.
    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        isAuthorized = granted
    }

    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - Schedule Refresh

    /// Re-schedules the next 7 days of reminders from scratch.
    /// Call after every workout completion and on app launch.
    func refresh(context: ModelContext, settings: UserSettings) async {
        await checkAuthorizationStatus()
        guard isAuthorized else { return }

        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let enrolments = fetchActiveEnrolments(context: context)
        let streak = fetchStreakState(context: context)?.currentStreak ?? 0
        let schedule = buildSchedule(from: enrolments)

        for (date, exerciseNames) in schedule {
            if settings.dailyReminderEnabled {
                scheduleDailyReminder(
                    for: date,
                    exercises: exerciseNames,
                    hour: settings.dailyReminderHour,
                    minute: settings.dailyReminderMinute
                )
            }
            if settings.streakProtectionEnabled {
                scheduleStreakProtection(
                    for: date,
                    exerciseCount: exerciseNames.count,
                    streak: streak,
                    hour: settings.streakProtectionHour,
                    minute: settings.streakProtectionMinute
                )
            }
        }
    }

    // MARK: - Cancel

    /// Call when any exercise is completed today to cancel the streak-protection nag.
    func cancelTodayStreakProtection() {
        let today = Calendar.current.startOfDay(for: .now)
        let id = "streak-protection-\(today.timeIntervalSince1970)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    // MARK: - Immediate Posts

    func postLevelUnlock(exerciseName: String, newLevel: Int, startsIn: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Level \(newLevel) unlocked!"
        content.body = "\(exerciseName) — Level \(newLevel) starts in \(startsIn) day\(startsIn == 1 ? "" : "s")"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "level-unlock-\(UUID())",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func postScheduleAdjustment(exerciseName: String, newDateDescription: String) {
        let content = UNMutableNotificationContent()
        content.title = "Schedule adjusted"
        content.body = "\(exerciseName) moved to \(newDateDescription)"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "schedule-adjustment-\(UUID())",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Private

    private func buildSchedule(from enrolments: [ExerciseEnrolment]) -> [Date: [String]] {
        let today = Calendar.current.startOfDay(for: .now)
        guard let weekOut = Calendar.current.date(byAdding: .day, value: 7, to: today) else { return [:] }
        var schedule: [Date: [String]] = [:]
        for enrolment in enrolments {
            guard let scheduled = enrolment.nextScheduledDate else { continue }
            let day = Calendar.current.startOfDay(for: scheduled)
            guard day >= today, day <= weekOut else { continue }
            let name = enrolment.exerciseDefinition?.name ?? "Exercise"
            schedule[day, default: []].append(name)
        }
        return schedule
    }

    private func scheduleDailyReminder(for date: Date, exercises: [String], hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Time to train"
        content.body = exercises.count == 1
            ? exercises[0]
            : "\(exercises.count) exercises today — \(exercises.joined(separator: ", "))"
        content.sound = .default
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let id = "daily-reminder-\(date.timeIntervalSince1970)"
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    private func scheduleStreakProtection(
        for date: Date,
        exerciseCount: Int,
        streak: Int,
        hour: Int,
        minute: Int
    ) {
        let content = UNMutableNotificationContent()
        if streak > 1 {
            content.title = "Don't break your streak"
            content.body = "\(streak)-day streak — \(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s") still waiting"
        } else {
            content.title = "Start building your streak"
            content.body = "\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s") due today"
        }
        content.sound = .default
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let id = "streak-protection-\(date.timeIntervalSince1970)"
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    private func fetchActiveEnrolments(context: ModelContext) -> [ExerciseEnrolment] {
        (try? context.fetch(FetchDescriptor<ExerciseEnrolment>(predicate: #Predicate { $0.isActive }))) ?? []
    }

    private func fetchStreakState(context: ModelContext) -> StreakState? {
        (try? context.fetch(FetchDescriptor<StreakState>()))?.first
    }
}
```

- [ ] **Build to verify no errors**

- [ ] **Commit:**
```bash
git add inch/inch/Services/NotificationService.swift
git commit -m "feat: add NotificationService for local notification scheduling"
```

---

## Chunk 2: App Integration

### Task 4: Register NotificationService in InchApp

**Files:**
- Modify: `inch/inch/inchApp.swift`

- [ ] **Add service property** after `let dataUpload`:
```swift
let notificationService = NotificationService()
```

- [ ] **Add to WindowGroup environment** after `.environment(dataUpload)`:
```swift
.environment(notificationService)
```

- [ ] **Add status check** in the `.task` block after `watchConnectivity.activate()`:
```swift
await notificationService.checkAuthorizationStatus()
```

- [ ] **Commit:**
```bash
git add inch/inch/inchApp.swift
git commit -m "feat: register NotificationService in app environment"
```

---

### Task 5: Detect level advance in WorkoutViewModel

The level advance happens inside `completeSession` when `scheduler.applyCompletion` returns an `updated` snapshot with a higher `currentLevel`. Add detection there.

**Files:**
- Modify: `inch/inch/Features/Workout/WorkoutViewModel.swift`

- [ ] **Add two properties** near the top of the class (after `var sessionTotalReps: Int = 0`):
```swift
private(set) var didAdvanceLevel: Bool = false
private(set) var newLevel: Int = 0
```

- [ ] **In `completeSession`**, capture the before/after comparison immediately after `applyCompletion`. The current code is:
```swift
let snapshot = EnrolmentSnapshot(enrolment)
let levelSnap = LevelSnapshot(levelDef)
let updated = scheduler.applyCompletion(
    to: snapshot,
    level: levelSnap,
    actualDate: sessionDate,
    totalReps: sessionTotalReps
)
let nextDate = scheduler.computeNextDate(enrolment: updated, level: levelSnap)
scheduler.writeBack(updated, to: enrolment, nextDate: nextDate)
```

Change to:
```swift
let snapshot = EnrolmentSnapshot(enrolment)
let levelSnap = LevelSnapshot(levelDef)
let updated = scheduler.applyCompletion(
    to: snapshot,
    level: levelSnap,
    actualDate: sessionDate,
    totalReps: sessionTotalReps
)
didAdvanceLevel = updated.currentLevel > snapshot.currentLevel
newLevel = updated.currentLevel
let nextDate = scheduler.computeNextDate(enrolment: updated, level: levelSnap)
scheduler.writeBack(updated, to: enrolment, nextDate: nextDate)
```

- [ ] **Build to verify no errors**

- [ ] **Commit:**
```bash
git add inch/inch/Features/Workout/WorkoutViewModel.swift
git commit -m "feat: detect level advance in WorkoutViewModel.completeSession"
```

---

### Task 6: Wire notifications in WorkoutSessionView

**Files:**
- Modify: `inch/inch/Features/Workout/WorkoutSessionView.swift`

- [ ] **Add environment access** after `@Environment(MotionRecordingService.self)`:
```swift
@Environment(NotificationService.self) private var notifications
```

- [ ] **Add computed helper** for settings (already has `@Query private var allSettings`):
```swift
private var settings: UserSettings? { allSettings.first }
```

- [ ] **Extend the `.complete` case** in `.onChange(of: viewModel.phase)`. After the existing HealthKit `Task { ... }`, add:
```swift
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
```

- [ ] **Build to verify no errors**

- [ ] **Commit:**
```bash
git add inch/inch/Features/Workout/WorkoutSessionView.swift
git commit -m "feat: request permission, refresh notifications, and post level-unlock on workout completion"
```

---

### Task 7: Wire showConflictWarnings into TodayViewModel

**Files:**
- Modify: `inch/inch/Features/Today/TodayViewModel.swift`
- Modify: `inch/inch/Features/Today/TodayView.swift`

- [ ] **In `TodayViewModel.loadToday(context:)`**, add a `showWarnings` parameter:
```swift
func loadToday(context: ModelContext, showWarnings: Bool = true) {
```

- [ ] **Wrap `detectConflictsForToday()` call:**
```swift
if showWarnings {
    detectConflictsForToday()
} else {
    conflictWarnings = [:]
}
```

- [ ] **In `TodayView`**, add a `showConflictWarnings` computed property. Note: `@Query private var allSettings: [UserSettings]` already exists in TodayView — do NOT redeclare it. Only add:
```swift
private var showConflictWarnings: Bool { allSettings.first?.showConflictWarnings ?? true }
```

- [ ] **Update the `loadToday` call site** in TodayView (wherever `viewModel.loadToday(context:)` is called):
```swift
viewModel.loadToday(context: modelContext, showWarnings: showConflictWarnings)
```

- [ ] **Commit:**
```bash
git add inch/inch/Features/Today/TodayViewModel.swift inch/inch/Features/Today/TodayView.swift
git commit -m "feat: respect showConflictWarnings setting in TodayViewModel"
```

---

## Chunk 3: Settings UI

### Task 8: Create NotificationsSettingsSection

**Files:**
- Create: `inch/inch/Features/Settings/NotificationsSettingsSection.swift`

- [ ] **Create the file:**

```swift
import SwiftUI
import InchShared

struct NotificationsSettingsSection: View {
    @Bindable var settings: UserSettings
    @Environment(\.openURL) private var openURL
    let isAuthorized: Bool

    var body: some View {
        if isAuthorized {
            Section("Notifications") {
                Toggle("Daily Reminder", isOn: $settings.dailyReminderEnabled)
                if settings.dailyReminderEnabled {
                    DatePicker(
                        "Reminder time",
                        selection: dailyReminderBinding,
                        displayedComponents: .hourAndMinute
                    )
                }

                Toggle("Streak Protection", isOn: $settings.streakProtectionEnabled)
                if settings.streakProtectionEnabled {
                    DatePicker(
                        "Protection time",
                        selection: streakProtectionBinding,
                        displayedComponents: .hourAndMinute
                    )
                }

                Toggle("Test Day Alerts", isOn: $settings.testDayNotificationEnabled)
                Toggle("Level Unlock Alerts", isOn: $settings.levelUnlockNotificationEnabled)
            }
        } else {
            Section("Notifications") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notifications are disabled")
                        .font(.subheadline)
                    Text("Enable in Settings → Notifications → Inch")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Open Settings") {
                        // "App-Prefs:NOTIFICATIONS" is the iOS 16+ deep-link to the app's
                        // notification settings. UIApplication.openNotificationSettingsURLString
                        // is UIKit (banned) so we use the string literal directly.
                        if let url = URL(string: "App-Prefs:NOTIFICATIONS") {
                            openURL(url)
                        }
                    }
                    .font(.caption)
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Private

    private var dailyReminderBinding: Binding<Date> {
        timeBinding(
            hour: $settings.dailyReminderHour,
            minute: $settings.dailyReminderMinute
        )
    }

    private var streakProtectionBinding: Binding<Date> {
        timeBinding(
            hour: $settings.streakProtectionHour,
            minute: $settings.streakProtectionMinute
        )
    }

    private func timeBinding(hour: Binding<Int>, minute: Binding<Int>) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: hour.wrappedValue,
                    minute: minute.wrappedValue,
                    second: 0,
                    of: .now
                ) ?? .now
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                hour.wrappedValue = c.hour ?? hour.wrappedValue
                minute.wrappedValue = c.minute ?? minute.wrappedValue
            }
        )
    }
}
```

- [ ] **Commit:**
```bash
git add inch/inch/Features/Settings/NotificationsSettingsSection.swift
git commit -m "feat: add NotificationsSettingsSection view"
```

---

### Task 9: Create ScheduleSettingsSection

**Files:**
- Create: `inch/inch/Features/Settings/ScheduleSettingsSection.swift`

- [ ] **Create the file:**

```swift
import SwiftUI
import InchShared

struct ScheduleSettingsSection: View {
    @Bindable var settings: UserSettings

    var body: some View {
        Section {
            Toggle("Show Conflict Warnings", isOn: $settings.showConflictWarnings)
        } header: {
            Text("Schedule")
        } footer: {
            Text("Warns you when test days or high-volume sessions conflict.")
        }
    }
}
```

- [ ] **Commit:**
```bash
git add inch/inch/Features/Settings/ScheduleSettingsSection.swift
git commit -m "feat: add ScheduleSettingsSection view"
```

---

### Task 10: Wire new sections into SettingsView

**Files:**
- Modify: `inch/inch/Features/Settings/SettingsView.swift`

- [ ] **Add environment access** for notifications at top of struct:
```swift
@Environment(NotificationService.self) private var notifications
```

- [ ] **Add both new sections** to the `List` in `body`, after `workoutSection`:
```swift
if let settings = viewModel.settings {
    NotificationsSettingsSection(
        settings: settings,
        isAuthorized: notifications.isAuthorized
    )
    ScheduleSettingsSection(settings: settings)
}
```

- [ ] **Build to verify no errors**

- [ ] **Commit:**
```bash
git add inch/inch/Features/Settings/SettingsView.swift
git commit -m "feat: add Notifications and Schedule sections to SettingsView"
```

---

## Verification

- [ ] Run on iPhone 16 Pro simulator
- [ ] Complete a workout — permission prompt appears
- [ ] In History → gear → Settings: Notifications section visible with toggles
- [ ] Toggle Daily Reminder off, complete another workout — verify no daily-reminder notification scheduled (check LLDB: `po UNUserNotificationCenter.current().pendingNotificationRequests()` or add a debug log in `refresh`)
- [ ] Toggle Show Conflict Warnings off — Today view shows no amber banners
- [ ] Streak protection time picker saves correctly (persists after reopening Settings)

---

## Files Summary

| Action | Path |
|--------|------|
| Modify | `Shared/Sources/InchShared/Models/UserSettings.swift` |
| Modify | `Shared/Sources/InchShared/Engine/SchedulingEngine.swift` |
| Create | `inch/inch/Services/NotificationService.swift` |
| Modify | `inch/inch/inchApp.swift` |
| Modify | `inch/inch/Features/Workout/WorkoutViewModel.swift` |
| Modify | `inch/inch/Features/Workout/WorkoutSessionView.swift` |
| Modify | `inch/inch/Features/Today/TodayViewModel.swift` |
| Modify | `inch/inch/Features/Today/TodayView.swift` |
| Create | `inch/inch/Features/Settings/NotificationsSettingsSection.swift` |
| Create | `inch/inch/Features/Settings/ScheduleSettingsSection.swift` |
| Modify | `inch/inch/Features/Settings/SettingsView.swift` |
