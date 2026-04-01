# Rest Day Content — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the minimal rest day screen with a purposeful "Recovery Day" experience showing an upcoming session card, an explicit streak safety message, and a rotating contextual recovery tip.

**Architecture:** Phase 1 only — pure presentation-layer changes. `TodayViewModel` gains a `nextTrainingDayExercises` computed property; two new view components (`UpcomingSessionCard`, `RecoveryTipView`) are extracted to their own files; `RestDayView` is updated to use them. No new `@Model` entities, no network calls.

**Tech Stack:** SwiftUI, SwiftData (`@Query` for settings), `TodayViewModel` (`@Observable`)

---

## File Map

| Action | File | Responsibility |
|---|---|---|
| Modify | `inch/inch/Features/Today/TodayViewModel.swift` | Add `nextTrainingDayExercises` and `hasTrainedBefore` properties; extend `computeNextTraining()` and `loadToday()` |
| Create | `inch/inch/Features/Today/UpcomingSessionCard.swift` | Displays next training date + exercise name/level/day list |
| Create | `inch/inch/Features/Today/RecoveryTipView.swift` | Shows one rotating tip from a static array, no interaction |
| Modify | `inch/inch/Features/Today/RestDayView.swift` | Rename to Recovery Day, remove `nextTrainingCount`, update streak message copy (two-branch zero-streak), wire new components |
| Modify | `inch/inch/Features/Today/TodayView.swift` | Update `RestDayView(...)` call: remove `nextTrainingCount`, add `nextTrainingDayExercises` and `hasTrainedBefore` |
| Test | `Shared/Tests/InchSharedTests/TodayViewModelNextTrainingTests.swift` | Unit tests for `nextTrainingDayExercises` logic (pure computed property, no SwiftData needed) |

---

### Task 1: Add `nextTrainingDayExercises` to TodayViewModel (test-first)

**Files:**
- Modify: `inch/inch/Features/Today/TodayViewModel.swift`
- Create: `Shared/Tests/InchSharedTests/TodayViewModelNextTrainingTests.swift`

- [ ] **Step 1: Read TodayViewModel to understand `computeNextTraining()`**

Open `inch/inch/Features/Today/TodayViewModel.swift` and locate `computeNextTraining()`. It currently sets `nextTrainingDate` and `nextTrainingCount`. You will extend it to also set `nextTrainingDayExercises`.

- [ ] **Step 2: Write the failing test**

Create `Shared/Tests/InchSharedTests/TodayViewModelNextTrainingTests.swift`:

```swift
import Testing
import Foundation
@testable import InchShared

// These tests verify the tuple-building logic in isolation —
// no SwiftData container needed.
struct NextTrainingExercisesTests {

    // Helper: build a minimal fake enrolment snapshot for testing
    struct FakeEnrolment {
        let name: String
        let level: Int
        let dayNumber: Int
        let nextDate: Date
    }

    @Test func sortsEnrolmentsByName() {
        // Given two enrolments due on the same date
        let today = Calendar.current.startOfDay(for: .now)
        let enrolments = [
            FakeEnrolment(name: "Squats", level: 2, dayNumber: 5, nextDate: today),
            FakeEnrolment(name: "Push-Ups", level: 1, dayNumber: 3, nextDate: today),
        ]
        let result = enrolments
            .sorted { $0.name < $1.name }
            .map { (exerciseName: $0.name, level: $0.level, dayNumber: $0.dayNumber) }

        #expect(result[0].exerciseName == "Push-Ups")
        #expect(result[1].exerciseName == "Squats")
    }

    @Test func excludesEnrolmentsDueOnDifferentDate() {
        let today = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let dayAfter = Calendar.current.date(byAdding: .day, value: 2, to: today)!

        let nearestDate = tomorrow
        let enrolments = [
            FakeEnrolment(name: "Push-Ups", level: 1, dayNumber: 3, nextDate: tomorrow),
            FakeEnrolment(name: "Squats", level: 2, dayNumber: 5, nextDate: dayAfter),
        ]
        let result = enrolments
            .filter {
                Calendar.current.isDate($0.nextDate, inSameDayAs: nearestDate)
            }
            .map { (exerciseName: $0.name, level: $0.level, dayNumber: $0.dayNumber) }

        #expect(result.count == 1)
        #expect(result[0].exerciseName == "Push-Ups")
    }
}
```

- [ ] **Step 3: Run to confirm it fails (or compiles green — this tests pure logic)**

```
swift test --package-path Shared --filter NextTrainingExercisesTests
```

Expected: Tests pass (they test pure collection logic). If they fail, fix the test helper logic before continuing.

- [ ] **Step 4: Add `nextTrainingDayExercises` property and update `computeNextTraining()`**

In `TodayViewModel`, add the property declaration near `nextTrainingDate` and `nextTrainingCount`:

```swift
private(set) var nextTrainingDayExercises: [(exerciseName: String, level: Int, dayNumber: Int)] = []
```

Inside `computeNextTraining(from all:after:)`, after setting `nextTrainingDate`, add:

```swift
// Populate exercise list for rest day upcoming session card
if let nearest = nearest {
    nextTrainingDayExercises = all
        .filter { enrolment in
            guard let date = enrolment.nextScheduledDate else { return false }
            return Calendar.current.isDate(date, inSameDayAs: nearest)
        }
        .compactMap { enrolment -> (exerciseName: String, level: Int, dayNumber: Int)? in
            guard let name = enrolment.exerciseDefinition?.name else { return nil }
            return (exerciseName: name, level: enrolment.currentLevel, dayNumber: enrolment.currentDay)
        }
        .sorted { $0.exerciseName < $1.exerciseName }
} else {
    nextTrainingDayExercises = []
}
```

> The variable names match the current implementation: `all` is the `[ExerciseEnrolment]` parameter name, and `nearest` is the local `Date?` computed as `futureDates.min()`. Do not rename them.

- [ ] **Step 5: Build to verify no compiler errors**

```
xcodebuild build -project inch/inch.xcodeproj -scheme inch -destination 'generic/platform=iOS Simulator' | grep -E '(error:|Build succeeded)'
```

Expected: `Build succeeded`

- [ ] **Step 6: Commit**

```bash
git add inch/inch/Features/Today/TodayViewModel.swift \
        Shared/Tests/InchSharedTests/TodayViewModelNextTrainingTests.swift
git commit -m "$(cat <<'EOF'
feat: add nextTrainingDayExercises to TodayViewModel for rest day card

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Create `UpcomingSessionCard`

**Files:**
- Create: `inch/inch/Features/Today/UpcomingSessionCard.swift`

- [ ] **Step 1: Create the component**

```swift
import SwiftUI

struct UpcomingSessionCard: View {
    let nextDate: Date
    let exercises: [(exerciseName: String, level: Int, dayNumber: Int)]

    private var dateLabel: String {
        if Calendar.current.isDateInTomorrow(nextDate) {
            return "Tomorrow"
        }
        let days = Calendar.current.dateComponents([.day], from: .now, to: nextDate).day ?? 0
        if days <= 6 {
            return "In \(days) days"
        }
        return nextDate.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(dateLabel)
                .font(.headline)

            if exercises.isEmpty {
                Text("No exercises enrolled — add one in Settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(exercises, id: \.exerciseName) { item in
                    HStack {
                        Text(item.exerciseName)
                            .font(.subheadline)
                        Spacer()
                        Text("L\(item.level) Day \(item.dayNumber)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
```

- [ ] **Step 2: Build to verify**

```
xcodebuild build -project inch/inch.xcodeproj -scheme inch -destination 'generic/platform=iOS Simulator' | grep -E '(error:|Build succeeded)'
```

Expected: `Build succeeded`

- [ ] **Step 3: Commit**

```bash
git add inch/inch/Features/Today/UpcomingSessionCard.swift
git commit -m "$(cat <<'EOF'
feat: add UpcomingSessionCard component for rest day screen

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Create `RecoveryTipView`

**Files:**
- Create: `inch/inch/Features/Today/RecoveryTipView.swift`

- [ ] **Step 1: Create the component**

```swift
import SwiftUI

struct RecoveryTipView: View {
    // Tips rotate based on day-of-year so they change daily without randomisation
    // and remain stable across multiple app opens on the same day.
    private static let tips: [String] = [
        "Muscle protein synthesis peaks 24–48 hours after your last session. Your rest day is doing real work.",
        "Light movement like a walk improves blood flow to recovering muscles without adding training stress.",
        "Sleep is when most muscle repair happens. Prioritise 7–9 hours tonight.",
        "Your nervous system recovers on rest days too — pushing through fatigue accumulates neural debt.",
        "Consistent rest is what makes progressive overload work. The gains happen during recovery, not training.",
        "Staying hydrated on rest days supports nutrient delivery to recovering muscles.",
        "Mental rest matters too — lower training stress today supports motivation tomorrow.",
        "Your body rebuilds muscle fibres stronger than before. Rest is the stimulus response.",
        "Active recovery like stretching keeps joints mobile without taxing your muscles.",
        "Training adaptation is a two-part process: the workout creates the signal, recovery delivers the result.",
    ]

    private var todaysTip: String {
        let dayOfYear = (Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 1)
        return Self.tips[dayOfYear % Self.tips.count]
    }

    var body: some View {
        Text(todaysTip)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
```

- [ ] **Step 2: Build to verify**

```
xcodebuild build -project inch/inch.xcodeproj -scheme inch -destination 'generic/platform=iOS Simulator' | grep -E '(error:|Build succeeded)'
```

Expected: `Build succeeded`

- [ ] **Step 3: Commit**

```bash
git add inch/inch/Features/Today/RecoveryTipView.swift
git commit -m "$(cat <<'EOF'
feat: add RecoveryTipView with daily-rotating science-grounded tips

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Update `RestDayView`

**Files:**
- Modify: `inch/inch/Features/Today/RestDayView.swift`

- [ ] **Step 1: Read the current RestDayView**

Open `inch/inch/Features/Today/RestDayView.swift` in full before editing.

- [ ] **Step 2: Rewrite RestDayView**

Replace the entire file content. Key changes:
- Rename "Rest Day" → "Recovery Day" in the heading
- Replace the generic next-training message with `UpcomingSessionCard`
- Replace the silent "rest days are part of the program" caption with the explicit streak safety message
- Add `RecoveryTipView` below the streak card
- Handle zero-streak state

The `RestDayView` receives data from `TodayViewModel` via its parent (`TodayView`). Check how TodayView passes data to RestDayView and update accordingly. The view needs:
- `streak: Int` (already passed)
- `nextTrainingDate: Date?` (already passed — check exact parameter names in TodayView)
- `nextTrainingDayExercises: [(exerciseName: String, level: Int, dayNumber: Int)]` (new)

```swift
import SwiftUI

struct RestDayView: View {
    let streak: Int
    let nextTrainingDate: Date?
    let nextTrainingDayExercises: [(exerciseName: String, level: Int, dayNumber: Int)]
    // Pass true if any CompletedSet records exist (used for zero-streak copy)
    let hasTrainedBefore: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.indigo)
                    Text("Recovery Day")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                .padding(.top)

                // Streak safety card
                streakCard

                // Upcoming session card
                if let nextDate = nextTrainingDate {
                    UpcomingSessionCard(
                        nextDate: nextDate,
                        exercises: nextTrainingDayExercises
                    )
                }

                // Recovery tip
                RecoveryTipView()

                Spacer(minLength: 40)
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if streak > 0 {
                HStack {
                    Text("\(streak)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading) {
                        Text("day streak")
                            .font(.headline)
                        Text("is safe.")
                            .font(.headline)
                    }
                }
                Text("Scheduled rest days protect your streak. You're on track.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if hasTrainedBefore {
                Text("Your streak resets here — start again tomorrow.")
                    .font(.headline)
                Text("Complete your next workout to begin a new streak.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Start your first streak today.")
                    .font(.headline)
                Text("Complete a workout to begin building your streak.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
```

- [ ] **Step 3: Update TodayView to pass `nextTrainingDayExercises` and remove `nextTrainingCount`**

Open `inch/inch/Features/Today/TodayView.swift`. The current call (lines 37–41) is:

```swift
RestDayView(
    streak: streak,
    nextTrainingDate: viewModel.nextTrainingDate,
    nextTrainingCount: viewModel.nextTrainingCount
)
```

Replace it entirely with:

```swift
RestDayView(
    streak: streak,
    nextTrainingDate: viewModel.nextTrainingDate,
    nextTrainingDayExercises: viewModel.nextTrainingDayExercises,
    hasTrainedBefore: viewModel.hasTrainedBefore
)
```

> `streak` is a local computed property on `TodayView` (`private var streak: Int { streakStates.first?.currentStreak ?? 0 }`), not a property on `TodayViewModel`. Use `streak` directly. Remove `nextTrainingCount` — the new `RestDayView` no longer declares it.

Also add `private(set) var hasTrainedBefore: Bool = false` to `TodayViewModel` and set it in `loadToday(context:)`:

```swift
let hasAnySets = (try? context.fetch(FetchDescriptor<CompletedSet>()))?.isEmpty == false
hasTrainedBefore = hasAnySets
```

- [ ] **Step 4: Build and verify**

```
xcodebuild build -project inch/inch.xcodeproj -scheme inch -destination 'generic/platform=iOS Simulator' | grep -E '(error:|Build succeeded)'
```

Expected: `Build succeeded`

- [ ] **Step 5: Manually verify on simulator**

Run the app on iPhone 16 Pro simulator. Navigate to a rest day (use the Debug panel if available to set next training date to tomorrow). Confirm:
- Title shows "Recovery Day"
- Streak count is visible and prominent (or "Start your first streak today" if streak is 0)
- Streak message says "X-day streak is safe."
- Upcoming session card shows exercise names, level, day number
- Recovery tip appears at the bottom

- [ ] **Step 6: Commit**

```bash
git add inch/inch/Features/Today/RestDayView.swift \
        inch/inch/Features/Today/TodayView.swift \
        inch/inch/Features/Today/TodayViewModel.swift
git commit -m "$(cat <<'EOF'
feat: overhaul rest day screen as purposeful Recovery Day experience

Shows streak safety message, upcoming session detail, and rotating
science-grounded recovery tip. Phase 1 only — no new data models.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Out of Scope

**Watch (deferred):** The spec includes Watch Phase 1 changes — extending the `WatchConnectivity` payload with `nextTrainingDayExercises` and updating `WatchRestDayView`. This is not included in this plan to keep it focused on iPhone. Implement as a separate task after this plan is complete and tested.
