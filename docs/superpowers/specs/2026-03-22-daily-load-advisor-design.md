# Daily Load Advisor — Design Spec

**Date:** 2026-03-22
**Status:** Approved for implementation

---

## Overview

The Daily Load Advisor is a pure-logic engine that recommends how many total exercises a user should complete on a given day. After a user completes one or more exercises, an advisory card on the Today screen shows a recommendation such as "We recommend up to 4 exercises today." The system is advisory only — it does not modify the schedule, prescriptions, or any stored state.

The system activates only after the first exercise completion of the day. Before that point, there is nothing to advise on.

---

## Goals

- Advise users on a healthy daily exercise volume based on what they have done and what is coming up
- Account for exercise intensity, muscle group fatigue, test day costs, and upcoming test days
- Be dynamic: adding a new exercise type only requires assigning it a cost tier, not writing new rules
- Produce recommendations that are explainable in one line of copy on the Today card

## Non-Goals

- Does not modify scheduling, rest day patterns, or rep prescriptions
- Does not enforce limits — the user can always train regardless of the recommendation
- Does not account for time-of-day, heart rate, or any sensor data
- Does not require user feedback input (RPE ratings, soreness ratings) to function

---

## Exercise Science Basis

The model is grounded in the following evidence-based principles:

1. **Weighted rep volume as load proxy.** Session RPE × duration (Foster 2001) is the gold-standard load measure but requires user input. For a no-friction advisory, rep volume weighted by exercise compound-ness is the best available proxy. Heavy compound exercises (squats, pull-ups) impose substantially higher neuromuscular and systemic fatigue than core stability work (dead bugs) even at similar rep counts.

2. **Training to failure costs more.** Sets performed to failure (test days) produce disproportionately more local muscular damage and neural fatigue than submaximal prescribed sets. Research supports a 1.5–2× fatigue premium for max-effort sets over equivalent submaximal work.

3. **Same-group compounding.** Training the same muscle group twice in one day compounds fatigue super-additively — the combined load exceeds the sum of individual loads due to nervous system saturation and glycogen depletion. A ×1.5 multiplier on the second exercise in a group captures this effect. This applies specifically to the lower/lower-posterior pair (squats + glute bridges share the glutes and hip extensors). Core exercises (sit-ups, dead bugs) do not meaningfully compound each other — sit-ups are a flexion movement, dead bugs are an anti-extension stability drill, they do not share primary movers, and both carry low systemic cost.

4. **Lookback window.** Prior 24-hour training is the strongest signal for current-day capacity. Yesterday's test day or high-compound-volume session leaves residual fatigue that meaningfully constrains today. Beyond 72 hours, recovery is substantially complete for recreational bodyweight athletes.

5. **Pre-test taper.** Reducing training volume 24–48 hours before a test day modestly improves max-rep performance (~2–5% for recreational athletes) by allowing partial neuromuscular recovery. Even a 1-day taper has measurable benefit.

6. **Rescheduled exercise as ACWR spike.** A missed exercise rescheduled to today represents an acute load increase above what the user's body has been conditioned to handle this week — analogous to an Acute:Chronic Workload Ratio spike. A ×1.25 premium reflects this elevated cost.

7. **Rest as implicit baseline.** No "rest bonus" is applied for extended rest periods. The base budget already represents a fully-recovered user. The absence of a lookback penalty is equivalent to accounting for adequate rest.

---

## Load Model

### Daily Budget

**Ceiling: 10 units**

This ceiling produces the following calibrated outcomes at base costs:
- All 6 exercises: 12 units → exceeds budget (correctly flags 6 as elevated-risk)
- 4 heavy exercises (squats + pull-ups + push-ups + sit-ups): 9 units → fits (correctly safe)
- 4 exercises with same-group compounding (squats + glute bridges + push-ups + sit-ups): 9 units → fits
- 2 core exercises only: 2 units → 8 remaining → correctly signals high headroom

### Exercise Base Costs

| Exercise ID | Exercise | Base Cost | Tier | Basis |
|---|---|---|---|---|
| `squats` | Squats | 3 | High | Largest muscle mass, 72h recovery, 90s rest timer default |
| `pull_ups` | Pull-Ups | 3 | High | Hardest exercise, strong neural demand, 90s rest timer default |
| `push_ups` | Push-Ups | 2 | Medium | Moderate compound, 60s rest timer default |
| `glute_bridges` | Glute Bridges | 2 | Medium | Lower-posterior isolation, 75s rest timer default |
| `sit_ups` | Sit-Ups | 1 | Low | Core endurance, fast recovery, 45s rest timer default |
| `dead_bugs` | Dead Bugs | 1 | Low | Core stability, minimal systemic fatigue, 45s rest timer default |

Cost tiers align with the rest timer defaults in the UX spec, which were calibrated to muscular demand. The cost table is the single source of truth for "high-cost" exercises (squats, pull-ups), used for both the budget calculation and the lookback penalty check.

### Same-Group Compounding Pairs

The `sameGroupMultiplier` fires when the exercise's compounding partner has already been worked today. This is **not** derived from `MuscleGroup.conflictGroups` (which exists for scheduling conflict detection). It is defined independently here:

| Exercise | Compounding Partner |
|---|---|
| Squats (`lower`) | Glute Bridges (`lowerPosterior`) |
| Glute Bridges (`lowerPosterior`) | Squats (`lower`) |

All other pairs have no compounding relationship. Upper push, upper pull, core flexion, and core stability are each standalone — no current exercise in the app shares overlapping primary movers with them. Core exercises (sit-ups, dead bugs) are explicitly excluded: despite sharing a conflict group for scheduling purposes, they target different movement patterns (flexion vs anti-extension stability) and both carry negligible systemic cost.

### Exercise-Level Multipliers

Applied per exercise when calculating its effective cost. Multipliers stack multiplicatively.

```
effectiveCost = baseCost × testMultiplier × sameGroupMultiplier × rescheduledMultiplier
```

| Multiplier | Value | Condition |
|---|---|---|
| `testMultiplier` | × 1.5 | The completed exercise was a test day |
| `sameGroupMultiplier` | × 1.5 | That exercise's compounding partner has already been completed today |
| `rescheduledMultiplier` | × 1.25 | The exercise was overdue (its `nextScheduledDate` was before today when the session began) |

**Example — squats test day after glute bridges:**
```
baseCost = 3
testMultiplier = 1.5         (it was a test day)
sameGroupMultiplier = 1.5    (glute bridges, the compounding partner, already done today)
rescheduledMultiplier = 1.0  (scheduled for today)
effectiveCost = 3 × 1.5 × 1.5 × 1.0 = 6.75
```

### Budget-Level Reductions

Applied to the ceiling before exercise costs are subtracted. Represent forward-looking and backward-looking fatigue context.

| Reduction | Value | Condition |
|---|---|---|
| `preTestTaper` | − 1 | Any enrolled exercise has a test day within the next 48 hours |
| `lookbackPenalty` | − 1 | Yesterday included a test day OR two or more high-cost exercises (squats / pull-ups) |

Both can apply simultaneously: minimum effective budget is 8 (ceiling 10 − 1 − 1).

The "high-cost" check for `lookbackPenalty` is performed inside `DailyLoadAdvisor`, which owns the cost tier definitions. It checks whether `yesterdayCompletions` contains two or more entries with `exerciseId` in `["squats", "pull_ups"]`, or any entry with `isTest == true`.

### Recommendation Derivation

```
effectiveBudget = 10 − preTestTaper − lookbackPenalty
budgetConsumed = Σ effectiveCost(each completed exercise today)
remainingBudget = max(0, effectiveBudget − budgetConsumed)

avgRemainingCost = average baseCost of due-but-not-yet-completed exercises today
                   (falls back to 2.0 if dueButNotDone is empty)

N_more = min(
    floor(remainingBudget / avgRemainingCost),
    dueButNotDone.count
)

recommendedTotal = completedToday.count + N_more
```

`recommendedTotal` is always `≥ completedToday.count`. The advisor never retroactively tells a user they have done too much — if the budget is exhausted or exceeded, `N_more = 0` and the recommendation equals the number already completed.

---

## Architecture

### New File: `DailyLoadAdvisor.swift`

Location: `Shared/Sources/InchShared/Engine/DailyLoadAdvisor.swift`

A pure value-type struct with a single entry point. No SwiftData dependencies, no UI dependencies, fully testable in isolation. Follows the same pattern as `SchedulingEngine` and `ConflictDetector`.

```swift
struct DailyLoadAdvisor {
    func recommend(context: DailyLoadContext) -> DailyLoadRecommendation
}
```

### Input: `DailyLoadContext`

```swift
struct DailyLoadContext: Sendable {
    /// Exercises completed so far today, one record per exercise (not per set).
    /// Collapsed from CompletedSet records by TodayViewModel before passing in.
    let completedToday: [CompletedExerciseRecord]

    /// Exercises due today that have not yet been completed.
    let dueButNotDone: [PendingExerciseRecord]

    /// Exercises that have a test day projected within the next 48 hours (excluding today).
    /// Carries the scheduled date so the advisor can identify the most imminent test day
    /// when multiple entries are present (for advisory copy selection).
    /// Populated from SchedulingEngine.projectSchedule() — see Context Assembly.
    let testDaysInNext48h: [(exerciseId: String, exerciseName: String, scheduledDate: Date)]

    /// Exercises completed yesterday, one record per exercise.
    /// Used for the lookback penalty check.
    let yesterdayCompletions: [CompletedExerciseRecord]
}

struct CompletedExerciseRecord: Sendable {
    let exerciseId: String
    let exerciseName: String        // from ExerciseDefinition.name, for LoadFactor copy
    let muscleGroup: MuscleGroup
    let isTest: Bool                // from any CompletedSet.isTest in the session (all sets share the same value)
    let wasRescheduled: Bool        // true if nextScheduledDate was before today when the session began
}

struct PendingExerciseRecord: Sendable {
    let exerciseId: String
    let exerciseName: String        // from ExerciseDefinition.name
    let muscleGroup: MuscleGroup
    let isTest: Bool
}
```

### Output: `DailyLoadRecommendation`

```swift
struct DailyLoadRecommendation: Sendable {
    /// Total exercises recommended for today (completed + remaining).
    /// Always >= completedToday.count.
    let recommendedTotal: Int

    /// Budget consumed by completed exercises (for debugging / transparency).
    let budgetUsed: Double

    /// Effective budget after taper and lookback reductions (for debugging / transparency).
    let effectiveBudget: Double

    /// Active signals that influenced the result, for advisory copy generation.
    let factors: [LoadFactor]
}

enum LoadFactor: Sendable {
    case preTestTaper(exerciseName: String, scheduledDate: Date)  // one factor per upcoming test day; TodayViewModel sorts by scheduledDate to pick copy
    case lookbackPenalty
    case testDayCompleted(exerciseName: String)
    case sameGroupCompounding(muscleGroup: MuscleGroup)
    case rescheduledExercise(exerciseName: String)
}
```

### Context Assembly (TodayViewModel)

`TodayViewModel` is responsible for building the `DailyLoadContext` and running the advisor. It does not perform load calculations itself.

#### Step 1 — Capture rescheduled status at view load (before any completions)

`nextScheduledDate` on `ExerciseEnrolment` is overwritten when `completeTrainingDay()` runs. To detect whether an exercise was overdue before it was completed, `TodayViewModel` must capture this at view load:

```swift
// At view load time — before any completions happen today
var rescheduledExerciseIds: Set<String> = []
for enrolment in activeEnrolments {
    if let scheduled = enrolment.nextScheduledDate,
       scheduled < Calendar.current.startOfDay(for: .now),
       let id = enrolment.exerciseDefinition?.exerciseId {
        rescheduledExerciseIds.insert(id)
    }
}
```

This set persists for the lifetime of the `TodayViewModel` instance (i.e., the day's session). It is used when constructing `CompletedExerciseRecord.wasRescheduled`.

#### Step 2 — Build `completedToday`

Query `CompletedSet` records where `sessionDate == today`. Group by `exerciseId`. For each unique `exerciseId`, produce one `CompletedExerciseRecord`:

```swift
let todaySets = // fetch CompletedSet where sessionDate == today
let grouped = Dictionary(grouping: todaySets, by: \.exerciseId)

let completedToday: [CompletedExerciseRecord] = grouped.compactMap { exerciseId, sets in
    guard let enrolment = activeEnrolments.first(where: { $0.exerciseDefinition?.exerciseId == exerciseId }),
          let definition = enrolment.exerciseDefinition,
          let anySet = sets.first else { return nil }
    return CompletedExerciseRecord(
        exerciseId: exerciseId,
        exerciseName: definition.name,
        muscleGroup: definition.muscleGroup,
        isTest: anySet.isTest,       // all sets in a session share the same isTest value
        wasRescheduled: rescheduledExerciseIds.contains(exerciseId)
    )
}
```

#### Step 3 — Build `dueButNotDone`

Active enrolments where `nextScheduledDate <= today` and no `CompletedSet` exists for `sessionDate == today`:

```swift
let completedIds = Set(completedToday.map(\.exerciseId))
let dueButNotDone: [PendingExerciseRecord] = activeEnrolments.compactMap { enrolment in
    // Use a calendar-day comparison rather than a timestamp comparison.
    // nextScheduledDate preserves the time component of lastCompletedDate, so
    // an exercise due today may have a time component that hasn't elapsed yet.
    guard enrolment.isActive,
          let scheduled = enrolment.nextScheduledDate,
          Calendar.current.startOfDay(for: scheduled) <= Calendar.current.startOfDay(for: .now),
          let definition = enrolment.exerciseDefinition,
          !completedIds.contains(definition.exerciseId) else { return nil }

    let currentLevel = enrolment.currentLevel
    let isTest = (definition.levels ?? [])
        .first(where: { $0.level == currentLevel })
        .map { $0.totalDays == enrolment.currentDay } ?? false

    return PendingExerciseRecord(
        exerciseId: definition.exerciseId,
        exerciseName: definition.name,
        muscleGroup: definition.muscleGroup,
        isTest: isTest
    )
}
```

#### Step 4 — Build `testDaysInNext48h`

Use `SchedulingEngine.projectSchedule()`. The existing snapshot convenience initialisers handle the bridging:

```swift
let engine = SchedulingEngine()
let startOfToday = Calendar.current.startOfDay(for: .now)
let fortyEightHoursFromNow = Date.now.addingTimeInterval(48 * 3600)
var testDaysInNext48h: [(exerciseId: String, exerciseName: String, scheduledDate: Date)] = []

// completedIds from Step 2 is available here
for enrolment in activeEnrolments {
    guard enrolment.isActive,
          let definition = enrolment.exerciseDefinition,
          let levelDef = (definition.levels ?? []).first(where: { $0.level == enrolment.currentLevel }),
          let rawStartDate = enrolment.nextScheduledDate else { continue }

    // Clamp startDate to today for overdue exercises.
    // If nextScheduledDate is in the past (exercise was missed), projecting from that
    // past date would anchor the entire rest-day chain to an old base date, producing
    // projected test day dates that are too early and could trigger false preTestTaper.
    let startDate = max(rawStartDate, startOfToday)

    let enrolmentSnapshot = EnrolmentSnapshot(enrolment)
    let levelSnapshot = LevelSnapshot(levelDef)
    let daySnapshots = (levelDef.days ?? []).map(DaySnapshot.init)

    let projected = engine.projectSchedule(
        enrolment: enrolmentSnapshot,
        level: levelSnapshot,
        days: daySnapshots,
        startDate: startDate,
        upTo: 5
    )

    // Only look at FUTURE test days (strictly after today) within the 48h window.
    // Excludes today's test days — whether already completed or still pending,
    // today's tests are not "upcoming" for taper purposes.
    // Note: this is run after completeTrainingDay() + writeBack() for any exercise
    // completed this session, so nextScheduledDate on completed exercises already
    // points to their next future date.
    if let upcomingTest = projected.first(where: {
        $0.isTest &&
        $0.scheduledDate > startOfToday &&
        $0.scheduledDate <= fortyEightHoursFromNow
    }) {
        testDaysInNext48h.append((
            exerciseId: definition.exerciseId,
            exerciseName: definition.name,
            scheduledDate: upcomingTest.scheduledDate
        ))
    }
}
```

#### Step 5 — Build `yesterdayCompletions`

Same pattern as `completedToday` but filtering `CompletedSet` where `sessionDate == yesterday`:

```swift
let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: .now))!
let yesterdaySets = // fetch CompletedSet where sessionDate falls within yesterday
// Group and map to CompletedExerciseRecord exactly as in Step 2
// wasRescheduled is irrelevant for yesterday's records; set to false
```

#### Step 6 — Run the advisor and display

```swift
let context = DailyLoadContext(
    completedToday: completedToday,
    dueButNotDone: dueButNotDone,
    testDaysInNext48h: testDaysInNext48h,
    yesterdayCompletions: yesterdayCompletions
)
let recommendation = DailyLoadAdvisor().recommend(context: context)
```

**When to run:** After each exercise completion, and on view load if `completedToday` is non-empty.
**When to show the card:** Only when `completedToday.count >= 1`.

---

## Advisory Card Copy

`TodayViewModel` selects copy based on the highest-priority `LoadFactor` in the result. The `DailyLoadAdvisor` does not produce copy — it reports which factors fired, in no particular order.

Priority order for the displayed reason (highest to lowest):

1. `.preTestTaper(exerciseName:, scheduledDate:)` → `"[Exercise] test in the next 2 days — saving energy for your best effort."` *(if multiple `.preTestTaper` factors are present, sort by `scheduledDate` ascending and use the first — the most imminent test)*
2. `.testDayCompleted(exerciseName:)` → `"You gave everything on the [exercise] test — take it easy from here."`
3. `.sameGroupCompounding(muscleGroup:)` → `"[Muscle group] worked twice today — keeping the recommendation conservative."`
4. `.lookbackPenalty` → `"Heavy session yesterday — a lighter day today will help recovery."`
5. `.rescheduledExercise(exerciseName:)` → `"Catch-up exercise today adds to your load — factor that in."`
6. `factors.isEmpty` → `"Balanced load today — you're on track."` *(shown only when no factors fired)*

---

## No New Data Model Entities

All inputs are derivable from existing SwiftData entities and existing engine types. No schema migration required.

---

## Testing

All tests live in `InchSharedTests/Engine/DailyLoadAdvisorTests.swift`, following Swift Testing patterns in CLAUDE.md.

### Core Budget Scenarios

- All 6 exercises at base cost → `budgetConsumed = 12 > 10` → `recommendedTotal = 6` (completed count, no more headroom)
- 4 heavy exercises (squats + pull-ups + push-ups + sit-ups) → `budgetConsumed = 9` → fits within 10 → `recommendedTotal ≥ 4`
- Core-only session (sit-ups + dead bugs) → `budgetConsumed = 2` → high headroom → `recommendedTotal` near full due count

### Multiplier Correctness

- Test day exercise → `effectiveCost = baseCost × 1.5`
- Same-group pair (glute bridges then squats) → squats `effectiveCost = 3 × 1.5 = 4.5`
- Core pair (sit-ups then dead bugs) → dead bugs `effectiveCost = 1 × 1.0 = 1` (no same-group multiplier for core)
- Rescheduled exercise → `effectiveCost = baseCost × 1.25`
- All three multipliers stacked → `effectiveCost = baseCost × 1.5 × 1.5 × 1.25`

### Budget Reductions

- Test day projected in next 48h → `effectiveBudget = 9`
- Yesterday's test day → `effectiveBudget = 9`
- Both active → `effectiveBudget = 8`
- Yesterday had 2 high-cost exercises (squats + pull-ups) → `effectiveBudget = 9`

### Boundary Conditions

- `recommendedTotal` never `< completedToday.count` — if budget is exhausted, `N_more = 0`
- `remainingBudget` floored at 0 (no negative budget)
- `dueButNotDone` is empty → `N_more = 0`; `recommendedTotal = completedToday.count`
- Two squats test days completed (extreme: `budgetConsumed = 4.5 + 4.5 = 9`) with pre-test taper active (`effectiveBudget = 9`) → `remainingBudget = 0` → `recommendedTotal = 2`
- `completedToday` is empty → context should not be built; advisor should not run (enforced in `TodayViewModel`, not in advisor itself)

### Factor Reporting

- Each factor type fires under its stated condition
- Multiple factors can fire simultaneously (e.g., `.preTestTaper` and `.lookbackPenalty` both active)
- `factors.isEmpty` when no signals apply (fresh day, no taper, no lookback, no compounding)
- Multiple `.preTestTaper` factors fire when two exercises both have test days within 48h

---

## Extension Points

The system generalises without changes to the engine logic:

- **New exercises:** Assign an `exerciseId` and a cost tier entry in the advisor's cost table. No new rules needed.
- **New same-group pairs:** Add the pair to the compounding table inside `DailyLoadAdvisor`. Does not require changes to `MuscleGroup.conflictGroups`.
- **User RPE input (future):** If an RPE rating is collected post-session, it can replace the exercise cost estimate. `CompletedExerciseRecord` can be extended with an optional `perceivedEffort: Double?` field; the advisor scales `baseCost` by this value when present.
- **Budget tuning:** The ceiling (10) and cost tiers are constants defined once. Adjusting them requires changing a single location.
