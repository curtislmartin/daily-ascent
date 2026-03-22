# Spec Audit — v1 & v1.1 Implementation vs Spec Documents

> **Purpose:** Audit the v1 and v1.1 implementation against the spec documents. For each item, check the actual code against the spec and report: ✅ Matches spec, ⚠️ Partially matches (explain gap), ❌ Doesn't match (explain what's wrong).
>
> **Pre-read before auditing:** `files/bodyweight-ux-design-v2.md`, `files/scheduling-engine.md`, `files/data-model.md`, `files/v1-1-features.md`, `files/architecture.md`
>
> For any ⚠️ or ❌, give the specific file and what needs to change.

---

## Scheduling & Data

- [ ] Does `computeNextDate` handle `extraRestBeforeTest` correctly? (Push-Ups L2/L3 get 4 days, Sit-Ups/Dead Bugs L2/L3 get 3 days before test)
- [ ] Does the failed test retry keep the user on the same day and apply the extra rest for retries?
- [ ] Does the inter-level gap correctly give 2 rest days between levels?
- [ ] Does the +1 pushback work correctly — rest gap calculated from actual completion date, not originally scheduled date?
- [ ] Does conflict detection catch: double tests on same day, test + same muscle group training on same day?
- [ ] Does conflict resolution push the lower-priority exercise and cascade re-check?
- [ ] Are `MuscleGroup.conflictGroups` correct — lower and lower_posterior conflict, core_flexion and core_stability conflict, upper_push and upper_pull do NOT conflict?

---

## Counting Modes

- [ ] Do Push-Ups, Pull-Ups, and Sit-Ups use post-set confirmation (ready → active timer → end set → confirm reps with target pre-filled)?
- [ ] Do Squats, Glute Bridges, and Dead Bugs use real-time tap counting?
- [ ] Can the user adjust +/− before confirming?
- [ ] Is the counting mode driven by the exercise's `countingMode` property from `exercise-data.json`?

---

## Rest Timers

- [ ] Are per-exercise defaults correct: Push-Ups 60s, Squats 90s, Sit-Ups 45s, Pull-Ups 90s, Glute Bridges 75s, Dead Bugs 45s?
- [ ] Can the user override rest timers in Settings?
- [ ] Does the rest timer show the next set's target reps?

---

## Today Dashboard

- [ ] Does it show only enrolled exercises that are due (`nextScheduledDate <= today`)?
- [ ] Does it show conflict warnings on affected cards?
- [ ] Do completed exercises show as checked off?
- [ ] Does it show a rest day message when nothing is due?
- [ ] Does the muscle group tag show on each card?

---

## Test Day Flow

- [ ] Does it show the ring/progress visualisation filling toward the target?
- [ ] Does passing unlock the next level with a celebration?
- [ ] Does failing block progression and show "retry next session"?
- [ ] Is immediate retry prevented — the user must wait for the rest gap?

---

## Streak

- [ ] Does completing at least one exercise on a training day maintain the streak?
- [ ] Do rest days NOT break the streak?
- [ ] Does completing zero exercises on a training day break the streak?

---

## Watch App

- [ ] Does the Watch show today's due exercises from synced data?
- [ ] Can the user start, complete sets, rest, and finish an exercise entirely on the Watch?
- [ ] Does the Watch support BOTH counting modes (real-time and post-set confirmation)?
- [ ] Do results sync back to the iPhone?
- [ ] Are haptics used: tap per rep count, warning at 10s rest remaining, triple tap on rest end?

---

## Sensor Recording

- [ ] Does Core Motion record accelerometer + gyroscope during active sets on both devices?
- [ ] Is recording started on set start and stopped on set end (not during rest)?
- [ ] Is data written to a file, not held in memory?
- [ ] Is the `SensorRecording` metadata created with the confirmed rep count as the label?

---

## Data Upload

- [ ] Is upload gated behind the user's consent toggle?
- [ ] Does it use `BGProcessingTask` with `requiresNetworkConnectivity` and `requiresExternalPower`?
- [ ] Does it upload to the Supabase endpoint per `backend-api.md`?

---

## HealthKit

- [ ] Is a single `HKWorkout` saved per training session (not per exercise)?
- [ ] Is the activity type `.functionalStrengthTraining`?
- [ ] Is authorization requested before the first workout, not at app launch?

---

## History (v1.1)

- [ ] Does it have Log and Stats segments?
- [ ] Is the log grouped by week with expandable day entries?
- [ ] Does the expanded entry show per-exercise actual vs target reps?
- [ ] Does the stats dashboard show total reps, current streak, best streak, session count?
- [ ] Is there a Swift Charts weekly volume chart?

---

## Notifications (v1.1)

- [ ] Are all 5 types implemented: daily reminder, streak protection, test day, level unlock, schedule adjustment?
- [ ] Is streak protection cancelled when an exercise is completed?
- [ ] Are notifications re-scheduled after each workout completion?
- [ ] Is permission requested after the first workout, not during onboarding?

---

## Exercise Detail (v1.1)

- [ ] Does it show the L1→L2→L3 progression bar?
- [ ] Is there a session history chart (Swift Charts)?
- [ ] Does it show upcoming scheduled days with set prescriptions?
- [ ] Can the user browse all days in a level?
- [ ] Can the user reset their level or jump to a different day?
