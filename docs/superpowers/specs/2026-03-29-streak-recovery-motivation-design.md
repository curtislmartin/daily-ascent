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
- The `longestStreak > 0` guard is intentional: it ensures recovery messaging is never shown to users who have not yet established a streak. Without it, a brand-new user with `currentStreak == 0` would immediately see the banner.

Streak reset already happens in `TodayViewModel.resetStreakForMissedDayIfNeeded()`. This is the trigger point for scheduling the notification.

## In-App Banner — `StreakRecoveryBanner`

### When it shows
- `streak == 0 && longestStreak > 0 && !viewModel.isRestDay`
- Shown on the Today screen only

### Placement
Between `TodaySessionBanner` and the exercise cards in `TodayView.exerciseList`.

### Dismiss behaviour
Stored in `@State var streakRecoveryDismissed: Bool` in `TodayView`. Resets each time the view is initialised (no persistence). The banner disappears naturally once a workout completes (streak > 0 again).

**Stated product decision:** The banner reappears on every app open while the streak is zero. This is intentional. The copy is gentle rather than urgent, and the banner has a dismiss button, so it does not constitute nagging. If the user ignores the app for several days in a row the banner will keep appearing — this is acceptable and consistent with the low-pressure tone.

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
Called from `TodayViewModel.resetStreakForMissedDayIfNeeded()` immediately after setting `currentStreak = 0`. Only scheduled if `nextTrainingDate` is non-nil.

`nextTrainingDate` is the `viewModel.nextTrainingDate` value, which is the earliest future date on which any active enrolment has a session due. Because the scheduling engine always advances `nextScheduledDate` to a future training day (never a calendar rest day), `nextTrainingDate` is always a non-rest day when non-nil.

If `nextTrainingDate` is nil (the user has no upcoming sessions — e.g. they have completed all programme days or have no active enrolments), no notification is scheduled. This is expected and correct.

### New method
`NotificationService.scheduleStreakRecovery(nextTrainingDate: Date)`

Schedules a `UNCalendarNotificationTrigger` for **8:00am** on `nextTrainingDate`.

**Re-scheduling behaviour:** The fixed identifier `"streak-recovery"` means any existing pending notification is replaced when this method is called. If the user opens the app on multiple consecutive zero-streak days, `scheduleStreakRecovery` is called each time but the delivery date is always `nextTrainingDate` — which is stable across opens for the same set of enrolments. At most one `"streak-recovery"` notification is ever pending. This is intentional.

### Notification content
- **Title:** "Time to get back to it"
- **Body:** "Everyone misses a day. Your exercises are ready — no streak needed to start."
- **Identifier:** `"streak-recovery"`
- **Sound:** default

### Cancellation

The `"streak-recovery"` identifier is added to the list of notifications removed inside `NotificationService.refresh()`. `refresh()` is called both on app launch (via `TodayView.task`) and after every workout completion (via `WorkoutSessionView`). This means:

- If the user completes a workout the same day the streak resets (before the notification fires), `refresh()` cancels the pending notification at workout completion.
- If the user restores their streak on the next training day (the notification's scheduled day), `refresh()` cancels it when the app is opened that morning before the 8am trigger.
- On any subsequent launch where the streak is restored, `refresh()` removes the notification as a safety net.

No separate cancel method is needed.

## Files to Change

| File | Change |
|---|---|
| `inch/inch/Features/Today/TodayView.swift` | Add `@State var streakRecoveryDismissed`, show `StreakRecoveryBanner` conditionally |
| `inch/inch/Features/Today/StreakRecoveryBanner.swift` | New file — banner view |
| `inch/inch/Features/Today/TodayViewModel.swift` | Call `notifications.scheduleStreakRecovery(nextTrainingDate:)` after streak reset |
| `inch/inch/Services/NotificationService.swift` | Add `scheduleStreakRecovery(nextTrainingDate:)`, cancel `"streak-recovery"` in `refresh()` |

## Out of Scope

- Persistent dismiss state across calendar days
- Streak recovery progress (e.g. "you need 3 days to beat your best") — future
- Watch notification — uses same APNs delivery, no extra work needed
