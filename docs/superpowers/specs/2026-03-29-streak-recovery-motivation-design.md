# Streak Recovery Motivation — Design Spec

**Date:** 2026-03-29
**Status:** Approved

## Overview

When a user misses a training day and their streak resets to zero, show a gentle motivational prompt both inside the app and via push notification. Tone is encouraging and low-pressure: "Everyone misses a day."

## Scope

Two surfaces:
1. In-app banner on the Today screen
2. Push notification scheduled for the morning of the next training day

## Data Layer

No new SwiftData fields required. The streak-break condition is derived from existing state:

- **Condition:** `currentStreak == 0 && longestStreak > 0 && !isRestDay`
- `currentStreak` and `longestStreak` come from `StreakState` (already queried in `TodayView`)
- `isRestDay` comes from `TodayViewModel`

Streak reset already happens in `TodayViewModel.resetStreakForMissedDayIfNeeded()`. This is the trigger point for scheduling the notification.

## In-App Banner — `StreakRecoveryBanner`

### When it shows
- `streak == 0 && longestStreak > 0 && !viewModel.isRestDay`
- Shown on the Today screen only

### Placement
Between `TodaySessionBanner` and the exercise cards in `TodayView.exerciseList`.

### Dismiss behaviour
Stored in `@State var streakRecoveryDismissed: Bool` in `TodayView`. Resets each time the view is initialised (no persistence). The banner disappears naturally once a workout completes (streak > 0 again). Showing it again on re-open is acceptable — it is gentle, not nagging.

### Copy
- **Headline:** "Everyone misses a day."
- **Body:** "Your streak starts fresh today — pick up where you left off."

### Styling
- SF Symbol: `arrow.counterclockwise` in `.secondary` colour
- No red, no warning styling
- Subdued card treatment consistent with other Today cards
- Dismiss (`×`) button top-trailing

## Push Notification

### Trigger
Called from `TodayViewModel.resetStreakForMissedDayIfNeeded()` immediately after setting `currentStreak = 0`. Only fires if `nextTrainingDate` is non-nil (derived from `viewModel.nextTrainingDate`, already computed in `loadToday`).

### New method
`NotificationService.scheduleStreakRecovery(nextTrainingDate: Date)`

Schedules a `UNCalendarNotificationTrigger` for **8:00am** on `nextTrainingDate`.

### Notification content
- **Title:** "Time to get back to it"
- **Body:** "Everyone misses a day. Your exercises are ready — no streak needed to start."
- **Identifier:** `"streak-recovery"` (fixed — re-scheduling replaces the previous one)
- **Sound:** default

### Cancellation
Cancelled in `NotificationService.cancelTodayStreakProtection()` alongside the streak-protection notification, since both are irrelevant once a workout completes. No separate cancel method needed.

Wait — actually, the streak-recovery notification is for the *next* training day, not today. It should be cancelled when a workout completes on that next training day (i.e., when the streak is restored). The safest approach: cancel `"streak-recovery"` inside `NotificationService.refresh()`, which is already called after every workout completion. Add `"streak-recovery"` to the list of identifiers removed during refresh.

## Files to Change

| File | Change |
|---|---|
| `inch/inch/Features/Today/TodayView.swift` | Add `@State var streakRecoveryDismissed`, show `StreakRecoveryBanner` conditionally |
| `inch/inch/Features/Today/StreakRecoveryBanner.swift` | New file — banner view |
| `inch/inch/Features/Today/TodayViewModel.swift` | Call `notifications.scheduleStreakRecovery(nextTrainingDate:)` after streak reset |
| `inch/inch/Services/NotificationService.swift` | Add `scheduleStreakRecovery(nextTrainingDate:)`, cancel `"streak-recovery"` in `refresh()` |

## Out of Scope

- Persistent dismiss (banner reappears on next open — acceptable)
- Streak recovery progress (e.g., "you need 3 days to beat your best") — future
- Watch notification — uses same APNs delivery, no extra work needed
