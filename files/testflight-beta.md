# Daily Ascent — TestFlight Beta Description

> **Purpose:** Beta testing information for TestFlight. Internal testing (up to 100 testers) doesn't require review. External testing (up to 10,000) requires Beta App Review on the first build.
>
> **Last updated:** 2026-03-16

---

## Beta App Description (required for external testing)

> Daily Ascent is a structured bodyweight training app with six exercises (Push-Ups, Squats, Sit-Ups, Pull-Ups, Glute Bridges, Dead Bugs), each with three progressive levels. The app schedules your training, counts your reps, manages rest periods, and tracks your progress toward max-rep tests that unlock the next level.
>
> This beta includes the full training experience on iPhone and Apple Watch, including injury-aware scheduling, two rep counting modes, HealthKit workout logging, workout history, streak tracking, and notifications.

---

## What to Test (for testers)

> We're looking for feedback on:
>
> - Does the scheduling feel right? Are rest days appropriate?
> - Is the workout flow clear — starting a set, counting reps, resting, moving to the next set?
> - Do both counting modes work well? (Tap counting for squats/bridges/dead bugs, timed sets for push-ups/pull-ups/sit-ups)
> - Does the Watch app work reliably? Do results sync back?
> - Is the data consent screen clear about what's being collected?
> - Any crashes, freezes, or unexpected behaviour?
>
> Report issues via TestFlight feedback or email support@clmartin.dev.

---

## Beta App Review Notes

> Daily Ascent has no login or user accounts. After installing, the tester selects exercises during onboarding and can immediately start training.
>
> Permissions requested at point of use:
> - HealthKit: before first workout save
> - Motion & Fitness: during first workout for sensor recording
> - Notifications: after first completed workout
>
> The data consent toggle defaults to OFF. Anonymous sensor data upload is optional.
>
> Privacy policy: https://clmartin.dev/daily-ascent/privacy

---

## Test Groups (suggested)

| Group | Who | Purpose |
|---|---|---|
| Internal | You + close collaborators (up to 100) | No review needed. Fast iteration. |
| External — Early | Trusted testers who'll give detailed feedback | Requires Beta App Review on first build. |
| External — Wider | Broader audience for stress testing | After initial bugs are resolved. |

---

## TestFlight Expiry Reminder

Builds expire after **90 days**. If your beta period is long, you'll need to upload fresh builds periodically to keep testers active.
