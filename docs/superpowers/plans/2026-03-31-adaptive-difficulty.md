# Adaptive Difficulty — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Detect when users are consistently struggling (completion ratio < 0.70 or "too hard" rating × 2) and respond with a day repeat; detect when they're breezing through ("too easy" × 3) and offer an early test; apply a 20% prescription reduction as a last resort after a failed repeat.

**Architecture:** New `AdaptationEngine` struct in `Shared` with a single `evaluate(enrolment:) -> AdaptationResult` function. Called twice per session by `WorkoutViewModel`: once after save (ratio signal only), once after the user submits a difficulty rating. New `DifficultyRating` enum with Sendable, raw-value strings. Five new properties added to `ExerciseEnrolment` (rolling windows + flags). `ExerciseCompleteView` gains a rating picker and displays adaptation messages. `WorkoutViewModel.load()` reads `sessionPrescriptionOverride` to multiply rep targets. `SchedulingEngine` reads `needsRepeat` to repeat the day.

**Tech Stack:** SwiftData schema V3 (ExerciseEnrolment changes), SwiftUI, Swift Testing for `AdaptationEngine` unit tests.

---

## Schema Migration Note

This plan adds 5 new properties to `ExerciseEnrolment`. These go into `BodyweightSchemaV3`. If Exercise Form Guidance plan (Task 1) or another plan has already created V3, simply add the new `ExerciseEnrolment` properties — no new schema version needed. If V3 doesn't exist yet, create it following the full V3 template in the Exercise Form Guidance plan (Task 1, Step 5).

---

## File Map

| Action | File | Responsibility |
|---|---|---|
| Modify | `Shared/Sources/InchShared/Models/ExerciseEnrolment.swift` | Add 5 adaptation properties |
| Modify | `Shared/Sources/InchShared/Models/BodyweightSchema.swift` | Ensure V3 includes ExerciseEnrolment changes |
| Modify | `Shared/Sources/InchShared/Utilities/ModelContainerFactory.swift` | Use `BodyweightMigrationPlan` if not already done |
| Create | `Shared/Sources/InchShared/Models/DifficultyRating.swift` | `enum DifficultyRating: String, CaseIterable, Sendable` |
| Create | `Shared/Sources/InchShared/Engine/AdaptationEngine.swift` | `AdaptationEngine` struct + `AdaptationResult` enum |
| Modify | `inch/inch/Features/Workout/WorkoutViewModel.swift` | Call engine after save + after rating; apply prescription override |
| Modify | `inch/inch/Features/Workout/ExerciseCompleteView.swift` | Add difficulty rating picker + adaptation message UI |
| Modify | `inch/inch/Features/Workout/WorkoutSessionView.swift` | Show "Lighter session" label when `sessionPrescriptionOverride` is set |
| Modify | `Shared/Sources/InchShared/Engine/SchedulingEngine.swift` | Read `needsRepeat` flag in `computeNextDate` |
| Test | `Shared/Tests/InchSharedTests/AdaptationEngineTests.swift` | Full unit test coverage for all 3 rules |

---

### Task 1: Schema — add adaptation properties to `ExerciseEnrolment`

**Files:**
- Modify: `Shared/Sources/InchShared/Models/ExerciseEnrolment.swift`
- Modify: `Shared/Sources/InchShared/Models/BodyweightSchema.swift`
- Modify: `Shared/Sources/InchShared/Utilities/ModelContainerFactory.swift`

- [ ] **Step 1: Write failing tests for new ExerciseEnrolment properties**

Create `Shared/Tests/InchSharedTests/AdaptationEngineTests.swift`:

```swift
import Testing
@testable import InchShared

struct ExerciseEnrolmentAdaptationTests {

    @Test func newEnrolmentHasEmptyRollingWindows() {
        let enrolment = ExerciseEnrolment()
        #expect(enrolment.recentDifficultyRatings.isEmpty)
        #expect(enrolment.recentCompletionRatios.isEmpty)
    }

    @Test func needsRepeatDefaultsFalse() {
        let enrolment = ExerciseEnrolment()
        #expect(enrolment.needsRepeat == false)
    }

    @Test func isRepeatSessionDefaultsFalse() {
        let enrolment = ExerciseEnrolment()
        #expect(enrolment.isRepeatSession == false)
    }

    @Test func sessionPrescriptionOverrideDefaultsNil() {
        let enrolment = ExerciseEnrolment()
        #expect(enrolment.sessionPrescriptionOverride == nil)
    }
}
```

- [ ] **Step 2: Run to confirm tests fail**

```
swift test --package-path Shared --filter ExerciseEnrolmentAdaptationTests
```

Expected: FAIL — properties not found.

- [ ] **Step 3: Add 5 new properties to `ExerciseEnrolment`**

In `Shared/Sources/InchShared/Models/ExerciseEnrolment.swift`, add after `restPatternIndex`:

```swift
// MARK: - Adaptive difficulty

/// Last 3 difficulty ratings as DifficultyRating.rawValue strings (rolling window)
public var recentDifficultyRatings: [String] = []

/// Last 3 session completion ratios: actualReps / prescribedReps (rolling window, 0.0–1.0)
public var recentCompletionRatios: [Double] = []

/// When true, scheduling engine repeats the current day instead of advancing
public var needsRepeat: Bool = false

/// True on the repeated session; cleared after it completes. Used by Rule 3 to detect
/// a failed repeat.
public var isRepeatSession: Bool = false

/// Multiplier applied to rep targets for the next session only (e.g. 0.80).
/// Cleared after the session saves. Nil means full prescription.
public var sessionPrescriptionOverride: Double? = nil
```

> **Do not add these to `init`.** SwiftData `@Model` properties with defaults do not need to be in `init` for the migration to work. The existing `init` remains unchanged.

- [ ] **Step 4: Ensure V3 is set up**

If `BodyweightSchemaV3` doesn't exist, create it following the template in Exercise Form Guidance plan Task 1 Step 5. If it exists, no changes needed — `ExerciseEnrolment.self` is already in the models list.

- [ ] **Step 5: Run tests to confirm they pass**

```
swift test --package-path Shared --filter ExerciseEnrolmentAdaptationTests
```

Expected: PASS

- [ ] **Step 6: Build app to verify**

```
xcodebuild build -project inch/inch.xcodeproj -scheme inch -destination 'generic/platform=iOS Simulator' | grep -E '(error:|Build succeeded)'
```

Expected: `Build succeeded`

- [ ] **Step 7: Commit**

```bash
git add Shared/Sources/InchShared/Models/ExerciseEnrolment.swift \
        Shared/Sources/InchShared/Models/BodyweightSchema.swift \
        Shared/Sources/InchShared/Utilities/ModelContainerFactory.swift \
        Shared/Tests/InchSharedTests/AdaptationEngineTests.swift
git commit -m "$(cat <<'EOF'
feat: add adaptive difficulty properties to ExerciseEnrolment (SchemaV3)

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Create `DifficultyRating` enum and `AdaptationEngine`

**Files:**
- Create: `Shared/Sources/InchShared/Models/DifficultyRating.swift`
- Create: `Shared/Sources/InchShared/Engine/AdaptationEngine.swift`

- [ ] **Step 1: Create `DifficultyRating.swift`**

```swift
/// Canonical difficulty rating values. Use these consistently across
/// view, engine, and analytics — never inline strings.
public enum DifficultyRating: String, CaseIterable, Sendable {
    case tooEasy    = "too_easy"
    case justRight  = "just_right"
    case tooHard    = "too_hard"
}
```

- [ ] **Step 2: Write the failing AdaptationEngine tests**

Add to `Shared/Tests/InchSharedTests/AdaptationEngineTests.swift`:

```swift
import Testing
@testable import InchShared

struct AdaptationEngineTests {

    // MARK: - Rule 1: Day Repeat

    @Test func noActionWhenBelowThreshold() {
        let enrolment = ExerciseEnrolment()
        enrolment.recentCompletionRatios = [0.90, 0.85]
        let result = AdaptationEngine().evaluate(enrolment: enrolment)
        #expect(result == .noAction)
    }

    @Test func repeatDayWhenTwoConsecutiveLowRatios() {
        let enrolment = ExerciseEnrolment()
        enrolment.recentCompletionRatios = [0.60, 0.65]  // both < 0.70
        let result = AdaptationEngine().evaluate(enrolment: enrolment)
        if case .repeatDay = result { /* pass */ } else {
            #expect(Bool(false), "Expected .repeatDay, got \(result)")
        }
    }

    @Test func repeatDayWhenTwoConsecutiveTooHardRatings() {
        let enrolment = ExerciseEnrolment()
        enrolment.recentDifficultyRatings = [
            DifficultyRating.tooHard.rawValue,
            DifficultyRating.tooHard.rawValue
        ]
        let result = AdaptationEngine().evaluate(enrolment: enrolment)
        if case .repeatDay = result { /* pass */ } else {
            #expect(Bool(false), "Expected .repeatDay, got \(result)")
        }
    }

    @Test func noRepeatWhenOnlyOneHardSession() {
        let enrolment = ExerciseEnrolment()
        enrolment.recentCompletionRatios = [0.90, 0.55]  // only last one is hard
        let result = AdaptationEngine().evaluate(enrolment: enrolment)
        #expect(result == .noAction)
    }

    @Test func onlyOneRepeatDayEvenIfBothSignalsPresent() {
        let enrolment = ExerciseEnrolment()
        enrolment.recentCompletionRatios = [0.55, 0.60]
        enrolment.recentDifficultyRatings = [
            DifficultyRating.tooHard.rawValue,
            DifficultyRating.tooHard.rawValue
        ]
        let result = AdaptationEngine().evaluate(enrolment: enrolment)
        // Should be exactly one repeatDay, not two
        if case .repeatDay = result { /* pass */ } else {
            #expect(Bool(false), "Expected .repeatDay, got \(result)")
        }
    }

    // MARK: - Rule 2: Early Test Eligibility

    @Test func earlyTestAfterThreeConsecutiveTooEasy() {
        let enrolment = ExerciseEnrolment()
        enrolment.recentDifficultyRatings = [
            DifficultyRating.tooEasy.rawValue,
            DifficultyRating.tooEasy.rawValue,
            DifficultyRating.tooEasy.rawValue
        ]
        let result = AdaptationEngine().evaluate(enrolment: enrolment)
        if case .earlyTestEligible = result { /* pass */ } else {
            #expect(Bool(false), "Expected .earlyTestEligible, got \(result)")
        }
    }

    @Test func noEarlyTestWithTwoTooEasy() {
        let enrolment = ExerciseEnrolment()
        enrolment.recentDifficultyRatings = [
            DifficultyRating.tooEasy.rawValue,
            DifficultyRating.tooEasy.rawValue
        ]
        let result = AdaptationEngine().evaluate(enrolment: enrolment)
        #expect(result == .noAction)
    }

    // MARK: - Rule 3: Prescription Reduction

    @Test func prescriptionReductionAfterFailedRepeat() {
        let enrolment = ExerciseEnrolment()
        enrolment.isRepeatSession = true
        enrolment.recentCompletionRatios = [0.90, 0.60]  // repeat session was also hard
        let result = AdaptationEngine().evaluate(enrolment: enrolment)
        if case .prescriptionReduction(let multiplier, _) = result {
            #expect(multiplier == 0.80)
        } else {
            #expect(Bool(false), "Expected .prescriptionReduction, got \(result)")
        }
    }

    @Test func noPrescriptionReductionIfRepeatSessionPassed() {
        let enrolment = ExerciseEnrolment()
        enrolment.isRepeatSession = true
        enrolment.recentCompletionRatios = [0.90, 0.85]  // repeat session was fine
        let result = AdaptationEngine().evaluate(enrolment: enrolment)
        #expect(result == .noAction)
    }
}
```

- [ ] **Step 3: Run to confirm tests fail**

```
swift test --package-path Shared --filter AdaptationEngineTests
```

Expected: FAIL — `AdaptationEngine` not found.

- [ ] **Step 4: Create `AdaptationEngine.swift`**

```swift
import Foundation

public enum AdaptationResult: Equatable {
    case noAction
    case repeatDay(message: String)
    case earlyTestEligible(message: String)
    case prescriptionReduction(multiplier: Double, message: String)
}

public struct AdaptationEngine {
    private static let hardCompletionThreshold: Double = 0.70
    private static let prescriptionReductionMultiplier: Double = 0.80

    public init() {}

    /// Evaluates adaptation rules in priority order.
    /// Called twice per session: once with ratio signal only, once with rating appended.
    public func evaluate(enrolment: ExerciseEnrolment) -> AdaptationResult {
        // Rule 3 (highest priority if repeat failed) — check before Rule 1
        if enrolment.isRepeatSession {
            let ratios = enrolment.recentCompletionRatios
            if let last = ratios.last, last < Self.hardCompletionThreshold {
                return .prescriptionReduction(
                    multiplier: Self.prescriptionReductionMultiplier,
                    message: "Lighter session today\nWe've adjusted today's sets to give you space to build. The full programme resumes next session."
                )
            }
        }

        // Rule 1: Day Repeat
        if twoConsecutiveHard(ratios: enrolment.recentCompletionRatios) ||
           twoConsecutiveTooHard(ratings: enrolment.recentDifficultyRatings) {
            return .repeatDay(
                message: "Tomorrow: one more run at this session\nToday was a tough one. We'll give you another go before moving on."
            )
        }

        // Rule 2: Early Test Eligibility
        if threeConsecutiveTooEasy(ratings: enrolment.recentDifficultyRatings) {
            return .earlyTestEligible(
                message: "Feeling strong? You can attempt the test early if you feel ready — or keep following the programme."
            )
        }

        return .noAction
    }

    // MARK: - Private signal evaluators

    private func twoConsecutiveHard(ratios: [Double]) -> Bool {
        guard ratios.count >= 2 else { return false }
        let last2 = ratios.suffix(2)
        return last2.allSatisfy { $0 < Self.hardCompletionThreshold }
    }

    private func twoConsecutiveTooHard(ratings: [String]) -> Bool {
        guard ratings.count >= 2 else { return false }
        let last2 = ratings.suffix(2)
        return last2.allSatisfy { $0 == DifficultyRating.tooHard.rawValue }
    }

    private func threeConsecutiveTooEasy(ratings: [String]) -> Bool {
        guard ratings.count >= 3 else { return false }
        let last3 = ratings.suffix(3)
        return last3.allSatisfy { $0 == DifficultyRating.tooEasy.rawValue }
    }
}
```

- [ ] **Step 5: Run tests to confirm they all pass**

```
swift test --package-path Shared --filter AdaptationEngineTests
```

Expected: All PASS. Fix any failures before continuing.

- [ ] **Step 6: Build app to verify**

```
xcodebuild build -project inch/inch.xcodeproj -scheme inch -destination 'generic/platform=iOS Simulator' | grep -E '(error:|Build succeeded)'
```

Expected: `Build succeeded`

- [ ] **Step 7: Commit**

```bash
git add Shared/Sources/InchShared/Models/DifficultyRating.swift \
        Shared/Sources/InchShared/Engine/AdaptationEngine.swift \
        Shared/Tests/InchSharedTests/AdaptationEngineTests.swift
git commit -m "$(cat <<'EOF'
feat: add AdaptationEngine with all 3 adaptation rules fully tested

Rule 1: day repeat on 2 consecutive hard sessions.
Rule 2: early test offer after 3 consecutive too-easy ratings.
Rule 3: 20% prescription reduction after a failed repeat session.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Update `SchedulingEngine` to read `needsRepeat`

**Files:**
- Modify: `Shared/Sources/InchShared/Engine/SchedulingEngine.swift`

- [ ] **Step 1: Read SchedulingEngine to understand `computeNextDate` / `writeBack`**

Open `Shared/Sources/InchShared/Engine/SchedulingEngine.swift`. Locate the method that computes the next training date and the `writeBack` method. You need to understand how `nextScheduledDate` is set.

- [ ] **Step 2: Write the failing test**

Add to `Shared/Tests/InchSharedTests/AdaptationEngineTests.swift`:

```swift
struct SchedulingEngineRepeatTests {

    @Test func nextDateIsRepeatedWhenNeedsRepeatTrue() throws {
        // Given an enrolment with needsRepeat = true
        // When computeNextDate is called
        // Then it returns the same day offset (not advancing day N+1)
        // This test verifies the scheduling engine honours the needsRepeat flag.
        // Read SchedulingEngine's test helpers to understand how to set up the fixture.
        // Reference scheduling-engine.md for the test fixture pattern.
        let engine = SchedulingEngine()
        let enrolment = ExerciseEnrolment(
            currentLevel: 1, currentDay: 3,
            lastCompletedDate: makeDate(2026, 4, 1),
            restPatternIndex: 0
        )
        enrolment.needsRepeat = true

        // When needsRepeat is true, the engine should schedule day 3 again
        // (same gap as normal, but NOT advancing currentDay)
        // The exact assertion depends on SchedulingEngine's implementation.
        // After reading SchedulingEngine.swift, write the specific assertion.
    }
}

private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
    Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
}
```

> After reading `SchedulingEngine.swift`, fill in the exact assertion. The spec says: when `needsRepeat = true`, `computeNextDate` returns the same day + standard rest gap (i.e., the day is repeated at the normal cadence). The `currentDay` does NOT advance.

- [ ] **Step 3: Implement the `needsRepeat` check in `SchedulingEngine`**

Read `SchedulingEngine.swift` fully. Find the `applyCompletion` or equivalent method that advances `currentDay`. Before advancing `currentDay`, check:

```swift
if snapshot.needsRepeat {
    // Don't advance day — repeat same day
    // Clear needsRepeat and set isRepeatSession
    var repeated = snapshot
    repeated.needsRepeat = false
    repeated.isRepeatSession = true
    // return with same currentDay, just compute next date at normal gap
    return repeated
}
```

The exact implementation depends on whether `SchedulingEngine` uses a snapshot pattern or operates directly on the model. Read the file carefully and adapt.

- [ ] **Step 4: After repeat completes, clear `isRepeatSession` and `needsRepeat`**

In `writeBack` (or the session completion path), after a session with `isRepeatSession = true` completes:
```swift
if enrolment.isRepeatSession {
    enrolment.isRepeatSession = false
    // needsRepeat was already cleared when the repeat was scheduled
}
```

- [ ] **Step 5: Run scheduling tests to verify nothing broke**

```
swift test --package-path Shared --filter SchedulingEngineTests
swift test --package-path Shared --filter SchedulingEngineRepeatTests
```

Expected: All existing tests PASS; new test PASS.

- [ ] **Step 6: Build app**

```
xcodebuild build -project inch/inch.xcodeproj -scheme inch -destination 'generic/platform=iOS Simulator' | grep -E '(error:|Build succeeded)'
```

Expected: `Build succeeded`

- [ ] **Step 7: Commit**

```bash
git add Shared/Sources/InchShared/Engine/SchedulingEngine.swift \
        Shared/Tests/InchSharedTests/AdaptationEngineTests.swift
git commit -m "$(cat <<'EOF'
feat: SchedulingEngine reads needsRepeat flag to repeat current day

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Apply `sessionPrescriptionOverride` in `WorkoutViewModel`

**Files:**
- Modify: `inch/inch/Features/Workout/WorkoutViewModel.swift`

- [ ] **Step 1: Read `WorkoutViewModel.load(context:)` and `currentPrescription(for:)`**

Find where `prescription` is set and where individual set rep targets are read. Rep targets come from `prescription.sets[currentSetIndex]`.

- [ ] **Step 2: Apply the override multiplier when loading the session**

In `load(context:)`, after setting `self.prescription`:

```swift
if let override = enrolment.sessionPrescriptionOverride {
    applyPrescriptionOverride(override)
}
```

Add a helper:

```swift
private func applyPrescriptionOverride(_ multiplier: Double) {
    guard var p = prescription else { return }
    let adjustedSets = p.sets.map { target in
        max(1, Int((Double(target) * multiplier).rounded()))
    }
    // DayPrescription.sets is likely a stored array — create a modified copy
    // Check DayPrescription.swift to see if it's a value type or reference type
    // and whether sets is mutable. Adapt accordingly.
    prescriptionOverrideMultiplier = multiplier  // stored for UI label display
}

private(set) var prescriptionOverrideMultiplier: Double? = nil
```

> If `DayPrescription` is a `@Model` class, do NOT mutate its `sets` — that would corrupt stored data. Instead, maintain a separate `var overriddenSets: [Int]?` on `WorkoutViewModel` and use it in `currentTargetReps`:

```swift
var currentTargetReps: Int {
    overriddenSets?[safe: currentSetIndex] ?? prescription?.sets[safe: currentSetIndex] ?? 0
}
```

- [ ] **Step 3: Clear the override after session saves**

In `completeSession(context:)`, after saving:

```swift
if enrolment.sessionPrescriptionOverride != nil {
    enrolment.sessionPrescriptionOverride = nil
    // isRepeatSession is cleared by SchedulingEngine on repeat completion
}
try? context.save()
```

- [ ] **Step 4: Build and verify**

```
xcodebuild build -project inch/inch.xcodeproj -scheme inch -destination 'generic/platform=iOS Simulator' | grep -E '(error:|Build succeeded)'
```

Expected: `Build succeeded`

- [ ] **Step 5: Commit**

```bash
git add inch/inch/Features/Workout/WorkoutViewModel.swift
git commit -m "$(cat <<'EOF'
feat: apply sessionPrescriptionOverride multiplier in WorkoutViewModel

Reduces rep targets by the stored multiplier for the "lighter session".
Override is cleared after the session completes.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Difficulty rating UI and adaptation messages in `ExerciseCompleteView`

**Files:**
- Modify: `inch/inch/Features/Workout/ExerciseCompleteView.swift`
- Modify: `inch/inch/Features/Workout/WorkoutViewModel.swift`
- Modify: `inch/inch/Features/Workout/WorkoutSessionView.swift`

- [ ] **Step 1: Add difficulty rating to `ExerciseCompleteView`**

Read the current `ExerciseCompleteView` in full. It shows rep count, previous session delta, and next session date. Add:

1. A new parameter `onRatingSubmitted: ((DifficultyRating) -> Void)?` (optional — nil if test day).
2. A new parameter `adaptationMessage: String?` — shown when non-nil after rating.
3. A "How did that feel?" section with three buttons:

```swift
// In ExerciseCompleteView body, below the rep count section:
if let onRating = onRatingSubmitted, !ratingSubmitted {
    VStack(spacing: 12) {
        Text("How did that feel?")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        HStack(spacing: 12) {
            ForEach([DifficultyRating.tooEasy, .justRight, .tooHard], id: \.self) { rating in
                Button(ratingLabel(rating)) {
                    ratingSubmitted = true
                    selectedRating = rating
                    onRating(rating)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}

if let message = adaptationMessage {
    Text(message)
        .font(.subheadline)
        .multilineTextAlignment(.center)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
}
```

Add `@State private var ratingSubmitted = false` and `@State private var selectedRating: DifficultyRating? = nil`.

Helper:
```swift
private func ratingLabel(_ rating: DifficultyRating) -> String {
    switch rating {
    case .tooEasy: return "Too easy"
    case .justRight: return "Just right"
    case .tooHard: return "Too hard"
    }
}
```

- [ ] **Step 2: Add adaptation state to `WorkoutViewModel`**

Add:
```swift
private(set) var adaptationMessage: String? = nil
private(set) var showMoveOnAnyway: Bool = false
```

- [ ] **Step 3: Wire the two-pass `AdaptationEngine` evaluation in `WorkoutViewModel`**

Pass 1 — after `completeSession()` saves (before `ExerciseCompleteView` appears):

```swift
// In completeSession(context:), after try? context.save():
if let enrolment {
    let result = AdaptationEngine().evaluate(enrolment: enrolment)
    applyAdaptationResult(result, to: enrolment, context: context, isPostRating: false)
}
```

Pass 2 — called when the user submits a rating. Add a new method:

```swift
func submitDifficultyRating(_ rating: DifficultyRating, context: ModelContext) {
    guard let enrolment else { return }
    // Append to rolling window (max 3)
    var ratings = enrolment.recentDifficultyRatings
    ratings.append(rating.rawValue)
    if ratings.count > 3 { ratings.removeFirst() }
    enrolment.recentDifficultyRatings = ratings
    try? context.save()

    let result = AdaptationEngine().evaluate(enrolment: enrolment)
    applyAdaptationResult(result, to: enrolment, context: context, isPostRating: true)
}

private func applyAdaptationResult(
    _ result: AdaptationResult,
    to enrolment: ExerciseEnrolment,
    context: ModelContext,
    isPostRating: Bool
) {
    switch result {
    case .noAction:
        adaptationMessage = nil
        showMoveOnAnyway = false
    case .repeatDay(let message):
        adaptationMessage = message
        showMoveOnAnyway = true
        enrolment.needsRepeat = true
        enrolment.isRepeatSession = false  // cleared; will be set on the next session
        try? context.save()
    case .earlyTestEligible(let message):
        adaptationMessage = message
        showMoveOnAnyway = false
    case .prescriptionReduction(let multiplier, let message):
        adaptationMessage = message
        showMoveOnAnyway = false
        enrolment.sessionPrescriptionOverride = multiplier
        try? context.save()
    }
}
```

- [ ] **Step 4: Wire `submitDifficultyRating` from `WorkoutSessionView` to `ExerciseCompleteView`**

In `WorkoutSessionView`, pass the rating callback to `ExerciseCompleteView`:

```swift
ExerciseCompleteView(
    exerciseName: viewModel.exerciseName,
    totalReps: viewModel.sessionTotalReps,
    previousSessionReps: viewModel.previousSessionReps,
    nextDate: /* next date */,
    adaptationMessage: viewModel.adaptationMessage,
    onRatingSubmitted: viewModel.isTestDay ? nil : { rating in
        viewModel.submitDifficultyRating(rating, context: modelContext)
    },
    onDone: { dismiss() }
)
```

Also, append the completion ratio to `recentCompletionRatios` in `completeSession()`:

```swift
// After saving all sets, compute and store completion ratio
let totalPrescribed = prescription?.sets.reduce(0, +) ?? 0
let ratio = totalPrescribed > 0 ? Double(sessionTotalReps) / Double(totalPrescribed) : 1.0
var ratios = enrolment.recentCompletionRatios
ratios.append(ratio)
if ratios.count > 3 { ratios.removeFirst() }
enrolment.recentCompletionRatios = ratios
```

- [ ] **Step 5: Show "Lighter session" label in `WorkoutSessionView`**

In `WorkoutSessionView`, show a label on the pre-set ready screen when `viewModel.prescriptionOverrideMultiplier != nil`:

```swift
if viewModel.prescriptionOverrideMultiplier != nil {
    Text("Lighter session today")
        .font(.caption)
        .foregroundStyle(.orange)
        .padding(.horizontal, 12).padding(.vertical, 4)
        .background(.orange.opacity(0.15), in: Capsule())
}
```

- [ ] **Step 6: Handle "Move on anyway" button**

In `ExerciseCompleteView`, add a parameter `showMoveOnAnyway: Bool` and a `onMoveOnAnyway: (() -> Void)?`:

```swift
if showMoveOnAnyway, let onMoveOn = onMoveOnAnyway {
    Button("Move on anyway") {
        onMoveOn()
    }
    .foregroundStyle(.secondary)
    .font(.footnote)
}
```

In `WorkoutViewModel`, add:
```swift
func moveOnAnyway(context: ModelContext) {
    guard let enrolment else { return }
    enrolment.needsRepeat = false
    adaptationMessage = nil
    showMoveOnAnyway = false
    try? context.save()
}
```

- [ ] **Step 7: Clear rolling windows on level transition**

In `completeSession()`, when `didAdvanceLevel` is true:

```swift
if didAdvanceLevel {
    enrolment.recentCompletionRatios = []
    enrolment.recentDifficultyRatings = []
    try? context.save()
}
```

- [ ] **Step 8: Guard against test days**

Test days must never trigger adaptation. In `submitDifficultyRating` and the ratio recording logic, add a guard:

```swift
guard !isTestDay else { return }
```

- [ ] **Step 9: Build and verify**

```
xcodebuild build -project inch/inch.xcodeproj -scheme inch -destination 'generic/platform=iOS Simulator' | grep -E '(error:|Build succeeded)'
```

Expected: `Build succeeded`

- [ ] **Step 10: End-to-end test on simulator**

1. Complete two workouts in a row with < 70% reps. On the second completion screen, a "Tomorrow: one more run" message should appear.
2. Tap "Too hard" twice. Verify the same message (not doubled).
3. Tap "Move on anyway" — verify needsRepeat is cleared.
4. Tap "Too easy" three times. Verify the early test offer appears.

- [ ] **Step 11: Commit**

```bash
git add inch/inch/Features/Workout/ExerciseCompleteView.swift \
        inch/inch/Features/Workout/WorkoutViewModel.swift \
        inch/inch/Features/Workout/WorkoutSessionView.swift
git commit -m "$(cat <<'EOF'
feat: add difficulty rating UI and adaptation messages to ExerciseCompleteView

Two-pass AdaptationEngine evaluation: once after save (ratio), once after
user submits rating. Day repeat, early test offer, and lighter session
messages shown inline. User can always override with "Move on anyway".

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```
