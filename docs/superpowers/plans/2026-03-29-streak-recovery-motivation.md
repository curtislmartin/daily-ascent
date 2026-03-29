# Streak Recovery Motivation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a gentle in-app banner and schedule a push notification when a user misses a training day and their streak resets to zero.

**Architecture:** `TodayViewModel` gains a `streakWasJustReset` flag set during streak-reset detection. `TodayView` reads this flag after `loadToday()` to schedule a recovery notification via `NotificationService`. A new `StreakRecoveryBanner` view is inserted at the top of the Today exercise list when `currentStreak == 0 && longestStreak > 0 && !isRestDay`.

**Tech Stack:** SwiftUI, `UNUserNotificationCenter`, SwiftData, existing `NotificationService` and `TodayViewModel` patterns.

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `inch/inch/Features/Today/TodayViewModel.swift` | Modify | Add `streakWasJustReset` flag; set it in `resetStreakForMissedDayIfNeeded`; call `computeNextTraining` unconditionally |
| `inch/inch/Services/NotificationService.swift` | Modify | Add `scheduleStreakRecovery(nextTrainingDate:)`; cancel `"streak-recovery"` in `refresh()` |
| `inch/inch/Features/Today/StreakRecoveryBanner.swift` | Create | Banner view — headline, body copy, dismiss button |
| `inch/inch/Features/Today/TodayView.swift` | Modify | Inject `NotificationService`; show banner; schedule notification after load |

---

## Task 1: Add `streakWasJustReset` flag to `TodayViewModel`

**Files:**
- Modify: `inch/inch/Features/Today/TodayViewModel.swift`

The flag lets `TodayView` know a streak reset just happened this load cycle so it can schedule the recovery notification. It resets at the top of every `loadToday()` call, so it's only `true` on the load where the reset occurred.

- [ ] **Step 1: Add the flag property**

In `TodayViewModel`, after `var nextTrainingCount: Int = 0`, add:

```swift
/// Set to true on the load cycle where resetStreakForMissedDayIfNeeded resets the streak.
/// Consumed by TodayView to schedule a recovery notification.
private(set) var streakWasJustReset: Bool = false
```

- [ ] **Step 2: Reset the flag at the top of `loadToday`**

At the very start of `func loadToday(context: ModelContext, showWarnings: Bool = true)`, before the `let today = ...` line, add:

```swift
streakWasJustReset = false
```

- [ ] **Step 3: Set the flag when the streak is reset**

In `resetStreakForMissedDayIfNeeded`, after `streakState.currentStreak = 0`, add:

```swift
streakWasJustReset = true
```

The full function body should now look like:
```swift
private func resetStreakForMissedDayIfNeeded(context: ModelContext, today: Date) {
    guard !isRestDay else { return }
    let streaks = (try? context.fetch(FetchDescriptor<StreakState>())) ?? []
    guard let streakState = streaks.first, streakState.currentStreak > 0 else { return }
    guard let lastActive = streakState.lastActiveDate else { return }
    guard let lastDue = streakState.lastDueDate else { return }

    let lastDay = Calendar.current.startOfDay(for: lastActive)
    let referenceDay = Calendar.current.startOfDay(for: lastDue)
    if lastDay < referenceDay {
        streakState.currentStreak = 0
        streakWasJustReset = true
        try? context.save()
    }
}
```

- [ ] **Step 4: Make `computeNextTraining` run unconditionally**

`nextTrainingDate` is used by `TodayView` to schedule the recovery notification, but currently `computeNextTraining` is only called inside `if isRestDay`. A streak reset always happens on a non-rest day, so `nextTrainingDate` would always be `nil` at the notification-scheduling site without this fix.

In `loadToday`, find:

```swift
if isRestDay {
    computeNextTraining(from: all, after: today)
}
```

Replace with:

```swift
computeNextTraining(from: all, after: today)
```

This is safe: `computeNextTraining` already handles the case where no future dates exist (it returns early via `guard let nearest = futureDates.min() else { return }`), and `RestDayView` continues to receive `nextTrainingDate` and `nextTrainingCount` as before.

- [ ] **Step 5: Build to verify**

```bash
cd /Users/curtismartin/Work/inch-project && bash scripts/build-device.sh 2>&1 | tail -5
```

Expected: `Done. Check your iPhone and paired Watch.` (no build errors)

- [ ] **Step 6: Commit**

```bash
git add inch/inch/Features/Today/TodayViewModel.swift
git commit -m "feat: add streakWasJustReset flag and unconditional next-training computation"
```

---

## Task 2: Add `scheduleStreakRecovery` to `NotificationService`

**Files:**
- Modify: `inch/inch/Services/NotificationService.swift`

Two changes: a new public method to schedule the notification, and adding `"streak-recovery"` to the identifiers removed in `refresh()`.

- [ ] **Step 1: Add `"streak-recovery"` to `refresh()` cancellation**

In `refresh(context:settings:)`, find this line:

```swift
.filter { $0.hasPrefix("daily-reminder-") || $0.hasPrefix("streak-protection-") }
```

Replace with:

```swift
.filter {
    $0.hasPrefix("daily-reminder-") ||
    $0.hasPrefix("streak-protection-") ||
    $0 == "streak-recovery"
}
```

- [ ] **Step 2: Add `scheduleStreakRecovery(nextTrainingDate:)`**

After the `cancelTodayStreakProtection()` method, add:

```swift
/// Schedules a gentle recovery notification for 8am on the next training day.
/// Uses a fixed identifier so re-scheduling always replaces the previous one.
/// Safe to call repeatedly — at most one pending "streak-recovery" notification exists.
func scheduleStreakRecovery(nextTrainingDate: Date) {
    let content = UNMutableNotificationContent()
    content.title = "Time to get back to it"
    content.body = "Everyone misses a day. Your exercises are ready — no streak needed to start."
    content.sound = .default

    var components = Calendar.current.dateComponents([.year, .month, .day], from: nextTrainingDate)
    components.hour = 8
    components.minute = 0

    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    let request = UNNotificationRequest(
        identifier: "streak-recovery",
        content: content,
        trigger: trigger
    )
    UNUserNotificationCenter.current().add(request)
}
```

- [ ] **Step 3: Build to verify**

```bash
cd /Users/curtismartin/Work/inch-project && bash scripts/build-device.sh 2>&1 | tail -5
```

Expected: `Done. Check your iPhone and paired Watch.`

- [ ] **Step 4: Commit**

```bash
git add inch/inch/Services/NotificationService.swift
git commit -m "feat: add streak recovery notification scheduling"
```

---

## Task 3: Create `StreakRecoveryBanner` view

**Files:**
- Create: `inch/inch/Features/Today/StreakRecoveryBanner.swift`

A subdued card — no red, no warning tone. Uses `arrow.counterclockwise` in secondary colour, a dismiss button top-trailing. Matches the visual style of other Today cards.

- [ ] **Step 1: Create the file**

Create `inch/inch/Features/Today/StreakRecoveryBanner.swift` with:

```swift
import SwiftUI

struct StreakRecoveryBanner: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "arrow.counterclockwise")
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text("Everyone misses a day.")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Your streak starts fresh today — pick up where you left off.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Everyone misses a day. Your streak starts fresh today. Dismiss button.")
    }
}

#Preview {
    StreakRecoveryBanner(onDismiss: {})
        .padding()
}
```

- [ ] **Step 2: Build to verify**

```bash
cd /Users/curtismartin/Work/inch-project && bash scripts/build-device.sh 2>&1 | tail -5
```

Expected: `Done. Check your iPhone and paired Watch.`

- [ ] **Step 3: Commit**

```bash
git add inch/inch/Features/Today/StreakRecoveryBanner.swift
git commit -m "feat: add StreakRecoveryBanner view"
```

---

## Task 4: Wire up banner and notification scheduling in `TodayView`

**Files:**
- Modify: `inch/inch/Features/Today/TodayView.swift`

Two additions:
1. Show `StreakRecoveryBanner` at the top of the exercise list when the condition is met.
2. After `loadToday()`, check `viewModel.streakWasJustReset` and schedule the recovery notification.

- [ ] **Step 1: Add `@Environment(NotificationService.self)` and `@State` dismiss flag**

`NotificationService` is already in the environment (injected in `inchApp.swift`). In `TodayView`, after the existing `@State private var nudgeDismissed = false` line, add:

```swift
@Environment(NotificationService.self) private var notifications
@State private var streakRecoveryDismissed = false
```

- [ ] **Step 2: Show `StreakRecoveryBanner` in `exerciseList`**

In the `exerciseList` computed property, inside the `LazyVStack`, after the `TodaySessionBanner(...)` call and before the `if showDemographicsNudge` block, add:

```swift
if streak == 0 && longestStreak > 0 && !viewModel.isRestDay && !streakRecoveryDismissed {
    StreakRecoveryBanner {
        streakRecoveryDismissed = true
    }
}
```

Note: `exerciseList` is only shown when `!viewModel.isRestDay` (the `Group` in `body` switches between `RestDayView` and `exerciseList`), so this guard is belt-and-suspenders. Include it anyway to match the spec condition exactly and stay correct if routing ever changes.

`longestStreak` is available via the existing `@Query private var streakStates: [StreakState]`. Add the computed property alongside the existing `streak` property:

```swift
private var longestStreak: Int { streakStates.first?.longestStreak ?? 0 }
```

- [ ] **Step 3: Schedule the notification after `loadToday` — both `.task` and `.onAppear`**

`TodayView` loads via both `.task` (initial mount) and `.onAppear` (every return to view). Both call `viewModel.loadToday()`, so both are potential trigger sites. Add the scheduling call in both places so it fires consistently.

Update `.task`:

```swift
.task {
    viewModel.loadToday(context: modelContext, showWarnings: showConflictWarnings)
    if viewModel.streakWasJustReset, let nextDate = viewModel.nextTrainingDate {
        notifications.scheduleStreakRecovery(nextTrainingDate: nextDate)
    }
    watchConnectivity.sendTodaySchedule(
        enrolments: viewModel.dueExercises,
        settings: settings
    )
}
```

Update `.onAppear`:

```swift
.onAppear {
    viewModel.loadToday(context: modelContext, showWarnings: showConflictWarnings)
    if viewModel.streakWasJustReset, let nextDate = viewModel.nextTrainingDate {
        notifications.scheduleStreakRecovery(nextTrainingDate: nextDate)
    }
}
```

Re-scheduling with the fixed `"streak-recovery"` identifier is safe — it replaces any pending notification. `nextTrainingDate` is stable across reloads for the same set of enrolments, so the delivery time does not drift.

- [ ] **Step 4: Build to verify**

```bash
cd /Users/curtismartin/Work/inch-project && bash scripts/build-device.sh 2>&1 | tail -5
```

Expected: `Done. Check your iPhone and paired Watch.`

- [ ] **Step 5: Commit**

```bash
git add inch/inch/Features/Today/TodayView.swift
git commit -m "feat: show streak recovery banner and schedule recovery notification"
```

---

## Task 5: Build, install on device, and upload to TestFlight

- [ ] **Step 1: Run the full upload script**

```bash
cd /Users/curtismartin/Work/inch-project && bash scripts/upload-testflight.sh 2>&1
```

Expected: `UPLOAD SUCCEEDED` with a delivery UUID.

- [ ] **Step 2: Commit build number bump**

```bash
git add -A && git commit -m "chore: bump build number to <N>"
```

---

## Manual Verification Checklist

To verify the feature works end-to-end on device:

1. **Banner appears after missed day**: Using the Debug panel (if available), reset the streak to 0 with a non-zero longestStreak and a lastDueDate in the past. Open the Today screen. The `StreakRecoveryBanner` should appear above the exercise list.

2. **Banner dismisses**: Tap the `×` button. The banner disappears. Open another tab and return — the banner reappears (ephemeral state, by design).

3. **Banner absent on rest day**: When `isRestDay == true`, the banner should not appear even with `currentStreak == 0 && longestStreak > 0`.

4. **Banner absent on zero-streak with no prior streak**: A brand-new user (`longestStreak == 0`) should never see the banner.

5. **Notification scheduled**: After a simulated streak reset, check scheduled notifications via the Debug panel or via `UNUserNotificationCenter.current().pendingNotificationRequests()`. A `"streak-recovery"` request should be present targeting 8am on `nextTrainingDate`.

6. **Notification replaced on re-open**: Open the app again (still zero streak). Only one `"streak-recovery"` notification should be pending.

7. **Notification cancelled after workout**: Complete any exercise. The `"streak-recovery"` notification should no longer be in the pending list (cancelled by `refresh()`).
