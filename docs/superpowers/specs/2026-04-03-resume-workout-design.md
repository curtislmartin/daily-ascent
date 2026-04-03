# Resume Workout Design

## Goal

When a workout is interrupted (app backgrounded and terminated by iOS) mid-session, allow the user to resume from the set they left off rather than having to restart from set 1.

## Background

`WorkoutViewModel` state is in-memory. If iOS terminates the app, the in-progress session is lost. However, every completed set is persisted immediately to SwiftData as a `CompletedSet` record. On re-entry to the workout, these records are the recovery anchor.

The user's experience today: open the exercise, workout opens at set 1, has to redo previously completed sets. Desired experience: open the exercise, see a prompt asking to resume or start over.

## Scope

- Resume is offered only when there are completed sets **today** (same calendar day) for the exercise that are fewer than the total prescribed set count.
- If the user comes back the next day, the exercise is still due (because `writeBack` was never called — the session never completed), but no resume is offered. They start fresh.
- No new data models or persistence. All required data exists in `CompletedSet`.

## Architecture

Changes span four locations:

| File | Change |
|---|---|
| `TodayViewModel.swift` | Add `inProgressTodayIds: Set<String>` |
| `TodayView.swift` | Pass `isInProgress` to `ExerciseCard` |
| `ExerciseCard.swift` | Add `isInProgress: Bool`, show subtle indicator |
| `WorkoutViewModel.swift` | Detect partial completion in `load()`, add `resumeSession()` / `restartSession()` |
| `WorkoutSessionView.swift` | Add `.confirmationDialog` bound to `viewModel.shouldOfferResume` |

## Behaviour

### Today view indicator

`TodayViewModel.inProgressTodayIds` is a `Set<String>` of exercise IDs that have at least one `CompletedSet` today but fewer than the prescribed set count. It is computed in `loadToday()` alongside the existing `completedTodayIds`, using the same `setsByExercise` dictionary already built there.

An exercise is in progress if:
- `completedCount > 0`
- `completedCount < prescribedCount`
- It is NOT in `completedTodayIds` (not fully complete)

`ExerciseCard` receives a new `isInProgress: Bool` parameter. When `true`, it shows a subtle "In progress" label. The indicator is intentionally unobtrusive — it signals that a resume is available without drawing attention to an incomplete session.

`TodayView` passes `isInProgress: viewModel.inProgressTodayIds.contains(exerciseId)` to each `ExerciseCard`.

### Resume detection in `WorkoutViewModel.load()`

After loading the prescription and before setting `phase = .ready`, `load()` queries today's `CompletedSet` records for this exercise:

```
let todayStart = Calendar.current.startOfDay(for: .now)
let todaySets = sets where exerciseId matches AND completedAt >= todayStart
let completedCount = todaySets.count
let totalSets = prescription.sets.count
```

If `completedCount > 0 && completedCount < totalSets`:
- Set `shouldOfferResume = true`
- Set `resumeSetCount = completedCount`
- Set `resumeSessionReps = todaySets.reduce(0) { $0 + $1.actualReps }`
- Do **not** fire the `workout_started` analytics event (deferred to `restartSession()` or `resumeSession()`)

`phase` still transitions to `.ready` at `currentSetIndex = 0`. The dialog appears on top; the user cannot interact with the underlying view while it is presented.

### New ViewModel properties

```swift
private(set) var shouldOfferResume: Bool = false
private(set) var resumeSetCount: Int = 0       // number of sets already done
private(set) var resumeSessionReps: Int = 0    // sum of actualReps for today's sets
```

### `resumeSession()`

Called when the user taps "Resume from set N":

1. `currentSetIndex = resumeSetCount`
2. `sessionTotalReps = resumeSessionReps`
3. Fire `workout_resumed` analytics event (exerciseId, level, dayNumber, resumedFromSet: resumeSetCount + 1)
4. `shouldOfferResume = false`

Phase remains `.ready`. The ready view updates to show "Start Set \(currentSetIndex + 1)".

### `restartSession()`

Called when the user taps "Start over" or dismisses the dialog:

1. Fire `workout_started` analytics event (same as the existing event in `load()`)
2. `shouldOfferResume = false`

`currentSetIndex` stays at 0, `sessionTotalReps` stays at 0. Normal flow continues.

### WorkoutSessionView — confirmation dialog

```swift
.confirmationDialog(
    "Resume workout?",
    isPresented: Bindable(viewModel).shouldOfferResume
) {
    Button("Resume from set \(viewModel.resumeSetCount + 1)") {
        viewModel.resumeSession()
    }
    Button("Start over", role: .destructive) {
        viewModel.restartSession()
    }
}
```

No cancel button. If the user dismisses by tapping outside (iOS default behaviour for confirmation dialogs), `shouldOfferResume` is set to `false` by the binding and `restartSession()` is NOT called — which means `workout_started` analytics is not fired. To handle this, `WorkoutSessionView` uses `.onChange(of: viewModel.shouldOfferResume)` to call `restartSession()` if `shouldOfferResume` transitions from `true` to `false` without either button being tapped.

Actually, the simpler approach: use an `onDismiss` closure on the `.confirmationDialog` modifier (not available directly), or just accept that outside-tap dismissal is equivalent to "Start over" — wire the dismiss path to call `restartSession()` by observing the binding going false while neither button was tapped.

**Simpler solution:** Add a local `@State private var resumeHandled = false` in `WorkoutSessionView`. Both buttons set `resumeHandled = true` before calling their respective ViewModel methods. Use `.onChange(of: viewModel.shouldOfferResume) { _, new in if !new && !resumeHandled { viewModel.restartSession() } }` to catch outside-tap dismissal. Reset `resumeHandled = false` after the dialog closes.

### sessionDate

On resume, `sessionDate = .now` (the time of re-entry). Previously saved sets have their original `sessionDate`. This minor inconsistency is acceptable — `sessionDate` is used for the HealthKit workout start time and the `sessionTotalReps` completion ratio; the streak and scheduling logic use `CompletedSet.sessionDate` which is set per-set.

### Test days

No special handling. Resume logic applies identically.

## Analytics events

| Event | When |
|---|---|
| `workout_started` | `restartSession()` is called (user chooses "Start over" or dismisses dialog, OR no resume is offered and `load()` proceeds normally) |
| `workout_resumed` | `resumeSession()` is called |

`workout_resumed` properties: `exerciseId`, `level`, `dayNumber`, `resumedFromSet` (1-based).

## Testing

Unit-testable logic in `WorkoutViewModel`:

1. `load()` with no today sets → `shouldOfferResume == false`
2. `load()` with `completedCount == totalSets` → `shouldOfferResume == false` (fully complete)
3. `load()` with `0 < completedCount < totalSets` → `shouldOfferResume == true`, `resumeSetCount == completedCount`, `resumeSessionReps == sum`
4. `load()` with today sets from a different exercise → `shouldOfferResume == false`
5. `resumeSession()` → `currentSetIndex == resumeSetCount`, `sessionTotalReps == resumeSessionReps`, `shouldOfferResume == false`
6. `restartSession()` → `currentSetIndex == 0`, `sessionTotalReps == 0`, `shouldOfferResume == false`

`TodayViewModel.inProgressTodayIds` logic is also unit-testable alongside existing streak/completion tests.
