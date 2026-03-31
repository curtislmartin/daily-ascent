# Adaptive Difficulty — Design Spec

**Date:** 2026-03-31
**Status:** Draft
**App:** Daily Ascent (iOS + watchOS bodyweight training)

---

## Problem

The program is fully prescribed. Users who consistently fall short of rep targets may feel overwhelmed and quit. Users who consistently exceed them may feel unchallenged and disengage. The placement test sets the right starting level, but there's no ongoing response to how users are actually performing. The program treats all users identically from day 1 onwards.

---

## Goals

- Detect when a user is genuinely struggling and respond constructively
- Detect when a user is finding the program too easy and open an early progression path
- Never silently change the program — always explain changes briefly and positively
- Preserve the integrity of the validated day sequence (do not alter rep values in the stored programme data)
- Minimise complexity to the scheduling engine

## Non-Goals

- Machine learning or algorithmic rep adjustment (requires data at scale — future phase)
- Automatic level downgrade (too significant for automatic triggering; user-initiated only)
- Deload weeks (valuable but requires new day-type scaffolding — future phase)
- Watch-side RPE input (iPhone only in v1)

---

## Design

### Signal 1 — Post-Session Difficulty Rating

A 3-option rating is shown at the bottom of the `ExerciseCompleteView` post-workout summary screen, below the existing rep count and session time:

```
How did that feel?
[ Too easy ]  [ Just right ]  [ Too hard ]
```

- Tapping any option is immediate and final — no confirmation step
- The response is stored on the `ExerciseEnrolment` entity as part of a recent ratings history
- If the user dismisses without rating, no response is recorded (nil, not a default)
- The prompt is shown after every session (not just when the app thinks adaptation might be needed)

This gives users a sense of autonomy and agency. Research on Self-Determination Theory confirms this is a direct driver of exercise adherence.

### Signal 2 — Objective Rep Completion

After each session, `WorkoutViewModel` computes the completion ratio:

```
completionRatio = actualRepsTotal / prescribedRepsTotal
```

This is already derivable from saved `CompletedSet` data. A ratio below 0.70 (less than 70% of prescribed reps completed) flags the session as a "hard completion."

Single-session signals are ignored — daily variation in performance due to sleep, stress, and nutrition is high. Adaptation triggers only on **two consecutive sessions** of the same exercise at the same day pattern.

---

## Adaptation Rules

### Rule 1 — Day Repeat (primary adaptation)

**Definition of "consecutive":** The last 2 entries in the rolling window are both hard. A hard session is: completion ratio < 0.70 OR rating == `.tooHard`. A single intervening "just right" session resets the consecutive count.

**Trigger:** The last 2 entries in `recentCompletionRatios` are both < 0.70, OR the last 2 entries in `recentDifficultyRatings` are both `.tooHard`. Either signal alone is sufficient — they are evaluated independently. If both signals point to "too hard" simultaneously, one `repeatDay` result is returned (not two).

**Action:** Flag the current day as requiring a repeat. The scheduling engine inserts one extra occurrence of day N before advancing to day N+1. The rest gap after the repeated day is preserved as normal.

This is implemented as a `needsRepeat: Bool` flag on `ExerciseEnrolment`. The scheduling engine already handles day pushes — this is a new input to the same mechanism.

**User communication:** Shown on the post-workout summary screen (before the user leaves the session):

> **Tomorrow: one more run at this session**
> Today was a tough one. We'll give you another go before moving on.
> [Move on anyway]

The "Move on anyway" button is always present. The user can override at any time.

**Framing:** Never "you failed" — always "let's try that again." The repeat is presented as mastery practice, not regression.

### Rule 2 — Early Test Eligibility (secondary signal)

**Trigger:** "Too easy" rating on 3 consecutive sessions for the same exercise

**Action:** Surface an optional prompt offering an early max-rep test:

> **Feeling strong on Push-Ups?**
> You're ahead of pace. You can attempt the Level 1 test now if you feel ready — or keep following the programme.
> [Attempt test]  [Keep going]

This does not change the schedule unless the user explicitly taps "Attempt test." If they do, the test is inserted as a new session at the next available date (respecting the standard rest gap), and the remaining programme days are replaced by level 2.

If the user taps "Keep going," the prompt is dismissed and does not reappear until a further 3 consecutive "too easy" ratings accumulate.

### Rule 3 — Prescription Reduction (fallback only)

**Trigger:** Completion ratio < 0.70 on the *same day* after a day repeat (i.e., the user failed the repeat session too)

**Action:** For the next session only, reduce the prescribed rep target for each set by 20% (rounded to nearest whole rep). This is a session-level override — it does not mutate the stored `exercise-data.json` day data.

The reduced session is labelled clearly:

> **Lighter session today**
> We've adjusted today's sets to give you space to build. The full programme resumes next session.

After the lighter session completes (regardless of completion ratio), the full prescription resumes. No further automatic adaptation occurs — if the user continues to struggle at this point, they should consider re-starting the level from day 1 (a manual action in Settings → Programmes).

---

## Data Model

### Changes to `ExerciseEnrolment`

```swift
// New properties on ExerciseEnrolment @Model:
var recentDifficultyRatings: [String] = []   // DifficultyRating.rawValue, last 3 entries
var recentCompletionRatios: [Double] = []    // last 3 sessions, 0.0–1.0
var needsRepeat: Bool = false                // scheduling engine reads this
var isRepeatSession: Bool = false            // set true on the repeated session; cleared on completion
var sessionPrescriptionOverride: Double? = nil  // multiplier (e.g. 0.80), cleared after use
```

**Canonical difficulty rating values** (use these consistently everywhere — view, engine, analytics):
```swift
enum DifficultyRating: String, CaseIterable, Sendable {
    case tooEasy    = "too_easy"
    case justRight  = "just_right"
    case tooHard    = "too_hard"
}
```

`recentDifficultyRatings` and `recentCompletionRatios` store only the last 3 values (rolling window). `[String]` and `[Double]` are stored as transformable by SwiftData and are compatible with CloudKit.

**Window clearing on level transition:** When `AdaptationEngine` detects a level advance, it clears both rolling arrays. This prevents stale difficulty data from a completed level influencing the next level's adaptation logic.

**Schema migration required:** These new properties constitute a schema change to `ExerciseEnrolment`. They must be included in `BodyweightSchemaV2` alongside the `Achievement` model and `UserSettings` additions. A `MigrationStage.lightweight` stage is sufficient — all new properties have default values.

### AdaptationEngine

A new lightweight `AdaptationEngine` struct in `Shared/Sources/InchShared/Engine/`:

```swift
struct AdaptationEngine {
    func evaluate(enrolment: ExerciseEnrolment) -> AdaptationResult
}

enum AdaptationResult {
    case noAction
    case repeatDay(message: String)
    case earlyTestEligible(message: String)
    case prescriptionReduction(multiplier: Double, message: String)
}
```

**Evaluation sequencing:** `AdaptationEngine.evaluate()` is called **twice** per session:

1. **After session saves, before `ExerciseCompleteView`:** Using completion ratio only (the user hasn't rated yet). This determines if a prescription reduction (Rule 3) applies to the next session's preview.
2. **After the user submits a difficulty rating:** The rating is appended to `recentDifficultyRatings`, then `evaluate()` is called again. This second call may produce a `repeatDay` result that wasn't present after the first call (if the rating triggered the 2-consecutive threshold). The `ExerciseCompleteView` shows the adaptation message from the second evaluation.

If no rating is submitted (user dismisses), only the first evaluation result applies.

---

## UX Flows

### After a hard session (day repeat offered)

```
ExerciseCompleteView
└── Difficulty rating: [Too easy] [Just right] [Too hard]
└── (After rating "Too hard" × 2 cumulative):
    "Today was a tough one — we'll give you another go before moving on."
    └── [Got it]  [Move on anyway]
```

If "Got it": `needsRepeat = true` saved. The scheduling engine repeats day N. `isRepeatSession` is set to `true` on the enrolment so Rule 3 can identify the repeat session later.
If "Move on anyway": `needsRepeat` stays false. Programme advances normally.
If app force-quit before responding: `needsRepeat` stays false — the conservative choice. The adaptation message will reappear if the pattern continues on the next session.

### After 3 easy sessions (early test)

```
ExerciseCompleteView
└── "Feeling strong on Push-Ups? You can attempt the Level 1 test now."
    └── [Attempt test]  [Keep going]
```

If "Attempt test":
- `enrolment.currentDay` is set to the test day index for the current level (the last day marked `isTest = true` in the level's `days` array)
- `WorkoutViewModel` loads the test-day prescription on next session start — this is identical to how a scheduled test day is handled
- The remaining non-test days are skipped
- `recentDifficultyRatings` and `recentCompletionRatios` are cleared

If "Keep going": `recentDifficultyRatings` is cleared. The prompt will not reappear until a further 3 consecutive `.tooEasy` ratings accumulate from the current position.

### After a failed repeat (Tier 2 — prescription reduction)

```
ExerciseCompleteView (next session preview)
└── "Lighter session today — we've adjusted the sets to give you space to build."
```

This is shown as a preview on the *previous* session's completion screen (so the user knows before they start). The `WorkoutSessionView` also shows a "Lighter session" label on the pre-set screen.

---

## Scheduling Engine Integration

The `needsRepeat` flag is read by `SchedulingEngine.computeNextDate(for:)`. When `true`, it returns the same date as the current session's date + the standard rest gap (i.e., repeats the day at the normal cadence). After the repeat session saves, `needsRepeat` is cleared.

`sessionPrescriptionOverride` is read by `WorkoutViewModel.loadSession()`. When non-nil, rep targets are multiplied by the override value and displayed to the user. The override is cleared after the session is saved.

No structural changes to the scheduling algorithm — both are additive flags on the existing model.

---

## Edge Case Handling

**`sessionPrescriptionOverride` on test days:** Test days are excluded from adaptation. If `sessionPrescriptionOverride` is set and the next session is a test day, the override is cleared without applying. Test days always use the full prescribed rep target.

**Prescription reduction minimum:** The override multiplier (0.80) is applied to each set's rep count and rounded to the nearest whole rep. Minimum 1 rep per set is always enforced. If a set's reduced target would be 0, it is set to 1.

**Watch sessions and adaptation:** `WatchCompletionReport` includes `actualReps: Int` per set. iPhone applies the completion ratio signal from Watch-completed sessions to the rolling window. Subjective rating (`.tooHard` etc.) is iPhone-only — Watch sessions never contribute to `recentDifficultyRatings`. If Rule 1 triggers from Watch session ratio alone, the adaptation prompt appears the next time the user opens the iPhone app (via `pendingCelebrations`-style mechanism on `TodayViewModel`). `sessionPrescriptionOverride` set from iPhone applies to the next session on either device — the Watch receives the reduced prescription as part of the next schedule sync.

## Scope Boundaries

- Adaptation applies to training days only — test days are never subject to day-repeat or prescription reduction
- Level downgrade is user-initiated only — accessible via Settings → Programmes → Reset to start of level. Never automatic.
- No adaptation for timed exercises in v1 — rep-based sessions only
- `isRepeatSession: Bool` is the marker that Rule 3 reads — it distinguishes a repeated session from a new day in the rolling window logic
