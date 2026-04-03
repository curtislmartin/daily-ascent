# Exercise Session Delete Design

## Goal

Allow the user to view a single exercise's session from history and optionally delete it. Deletion removes the `CompletedSet` records and, if the session was fully completed, reconstructs the enrolment's progress state from the remaining history.

## Background

Every completed set is persisted immediately as a `CompletedSet` record. When all prescribed sets for an exercise are done, `writeBack` advances the enrolment: `currentDay`, `currentLevel`, `lastCompletedDate`, `nextScheduledDate`, `restPatternIndex`.

If a user performs a session incorrectly (wrong movement, accidental workout) and wants to remove it, there is currently no way to do so. The History log shows day-level summaries with inline exercise expansion but no drill-down or delete action.

A partial session (user quit before finishing) has its `CompletedSet` records saved but `writeBack` was never called — enrolment state is unaffected, only the records need deleting.

A fully completed session requires both deleting the records and rolling back the enrolment to the state it was in before that session was completed.

## Scope

- Single exercise session drill-down from the History log
- Delete with enrolment rollback where applicable
- No changes to scheduling, streak, or sensor recording logic
- No bulk delete

---

## Architecture

### Files

| File | Change |
|---|---|
| `inch/inch/Features/History/ExerciseSessionDetailView.swift` | **New** — dedicated view for one exercise's session |
| `inch/inch/Features/History/DayGroupRow.swift` | Modify — make `ExerciseSummaryRow` items navigable |
| `inch/inch/Features/History/HistoryViewModel.swift` | Modify — add `deleteSession(exerciseId:date:context:)` |
| `inch/inch/Navigation/NavigationDestinations.swift` | Modify — add `exerciseSession(ExerciseSessionDestination)` destination |

---

## UI Flow

### History → Session Detail

`DayGroupRow` currently expands inline to show `ExerciseSummaryRow` items. Each row becomes a `NavigationLink` that pushes `ExerciseSessionDetailView`, passing `exerciseId: String` and `sessionDate: Date`.

### ExerciseSessionDetailView

```
[Exercise Name]                           ← navigation title
[Date, abbreviated]                       ← subtitle / inline title display mode

List (insetGrouped):
  Section "Sets":
    Set 1    22 reps     (target 20)
    Set 2    18 reps     (target 24)
    Set 3    —           (not completed)   ← grey, only shown for partial sessions

  Section "Summary":
    Completed   2 of 5 sets
    Total       40 reps

  Section (no header):
    [Delete Session]                       ← destructive red button
```

For timed exercises, sets show `Xs hold` and `target Ys` instead of reps.

Partial sets (prescribed but not completed) are shown greyed out so the user can see how far through the session they got.

The delete button triggers a `confirmationDialog` (not an alert) — matching the quit-workout pattern in `WorkoutSessionView`.

---

## Deletion Logic

Implemented as `HistoryViewModel.deleteSession(exerciseId:date:context:)`. `HistoryViewModel` does not hold a `ModelContext` — the view passes `@Environment(\.modelContext)` to this method, consistent with how other view models in this codebase receive the context.

### Step 1 — Identify the session

Fetch all `CompletedSet` records where:
- `exerciseId == exerciseId`
- `sessionDate >= startOfDay(date)`
- `sessionDate < startOfDay(date) + 1 day`

Determine if the session was **complete**: `completedSets.count >= prescribedSetCount`.

`prescribedSetCount` comes from the enrolment's current prescription — but since the session may have been from a past day, use the `dayNumber` and `level` from the sets themselves to look up the correct `DayPrescription`.

### Step 2 — Delete the records

Delete all fetched `CompletedSet` records from the `ModelContext`. Call `context.save()`.

### Step 3 — Rollback enrolment (complete sessions only)

If the session was partial, stop here. `writeBack` was never called.

If the session was complete, reconstruct enrolment state:

1. Fetch all remaining `CompletedSet` records for this `exerciseId`, ordered by `sessionDate` descending.

2. **No sets remain:** Reset enrolment to:
   - `currentLevel = 1`
   - `currentDay = 1`
   - `lastCompletedDate = nil`
   - `nextScheduledDate = nil`
   - `restPatternIndex = 0`

3. **Sets remain:** Use the most recent set (`lastSet`) to determine next state:

   | Condition | `currentLevel` | `currentDay` |
   |---|---|---|
   | `lastSet.isTest && lastSet.testPassed == true` | `lastSet.level + 1` | `1` |
   | `lastSet.isTest && testPassed != true` | `lastSet.level` | `lastSet.dayNumber` (retry) |
   | Normal day | `lastSet.level` | `lastSet.dayNumber + 1` |

   Then:
   - `lastCompletedDate = lastSet.sessionDate`
   - `restPatternIndex = (currentDay - 1) % levelDefinition.restDayPattern.count`
   - `nextScheduledDate` — compute via `SchedulingEngine.computeNextDate(for:)` using an `EnrolmentSnapshot` built from the reconstructed state

4. Call `context.save()`.

### Edge case: level 3 test passed (max level)

If `lastSet.level == 3 && lastSet.isTest && lastSet.testPassed == true`, the exercise is fully complete. Set `currentLevel = 3`, `currentDay = lastSet.dayNumber + 1` (beyond the final day), treat as programme complete. No `nextScheduledDate` needed.

---

## Navigation

Follow the existing enum pattern in `NavigationDestinations.swift`. Add a new case to `HistoryDestination`:

```swift
enum HistoryDestination: Hashable {
    case exerciseDetail(PersistentIdentifier)
    case exerciseSession(exerciseId: String, sessionDate: Date)  // new
}
```

Add a case to `withHistoryDestinations()`:

```swift
case .exerciseSession(let exerciseId, let sessionDate):
    ExerciseSessionDetailView(exerciseId: exerciseId, sessionDate: sessionDate)
```

In `DayGroupRow`, wrap each `ExerciseSummaryRow` in a `NavigationLink(value:)` when expanded:

```swift
ForEach(day.exercises) { exercise in
    NavigationLink(value: HistoryDestination.exerciseSession(
        exerciseId: exercise.id,
        sessionDate: day.id
    )) {
        ExerciseSummaryRow(exercise: exercise)
    }
}
```

---

## Testing

`deleteSession` is in `HistoryViewModel` (app target, no test infrastructure). Verify by:

1. Complete an exercise fully → open history → drill into that session → delete → confirm exercise is due again (progress rolled back)
2. Partially complete an exercise → quit → open history → drill into partial session → delete → confirm no resume prompt on next open
3. Delete only session for an exercise → confirm enrolment resets to level 1 day 1
4. Delete a test-day session that caused a level advance → confirm level reverts
