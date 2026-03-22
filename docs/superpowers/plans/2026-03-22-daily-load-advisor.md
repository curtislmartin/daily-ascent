# Daily Load Advisor Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a pure-logic engine that returns a rich `LoadAdvisory` struct (or nil) to `TodayViewModel`, giving the Today card enough data to generate meaningful copy about how many exercises to do today and why.

**Architecture:** A stateless `DailyLoadAdvisor` struct in the Shared package receives a `DailyLoadContext` snapshot built by `TodayViewModel` and returns `LoadAdvisory?` (nil until the first exercise is completed). `LoadAdvisory` carries the recommended count plus muscle group fatigue signals, taper/penalty flags, and budget fraction — the card owns all copy decisions. `TodayViewModel` owns context assembly from SwiftData. No new data model entities.

**Tech Stack:** Swift 6.2, Swift Testing, SwiftData, existing `SchedulingEngine` / `EnrolmentSnapshot` / `LevelSnapshot` / `DaySnapshot` APIs.

**Spec:** `docs/superpowers/specs/2026-03-22-daily-load-advisor-design.md`

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `Shared/Sources/InchShared/Engine/DailyLoadContext.swift` | Create | Input value types: `DailyLoadContext`, `CompletedExerciseRecord`, `PendingExerciseRecord` |
| `Shared/Sources/InchShared/Engine/LoadAdvisory.swift` | Create | Output value type returned by `DailyLoadAdvisor.recommend()` |
| `Shared/Sources/InchShared/Engine/DailyLoadAdvisor.swift` | Create | Pure load calculation — budget, cost tiers, multipliers, reductions → returns `LoadAdvisory?` |
| `Shared/Tests/InchSharedTests/Engine/DailyLoadAdvisorTests.swift` | Create | All advisor logic tests |
| `Shared/Tests/InchSharedTests/TestTags.swift` | Modify | Add `.loadAdvisor` tag |
| `inch/inch/Features/Today/TodayViewModel.swift` | Modify | Add `advisory: LoadAdvisory?`, context assembly, call advisor after each load |

---

## Chunk 1: Engine types and core logic

### Task 1: Add `.loadAdvisor` test tag

**Files:**
- Modify: `Shared/Tests/InchSharedTests/TestTags.swift`

- [ ] Open `Shared/Tests/InchSharedTests/TestTags.swift` and add the new tag:

```swift
import Testing

extension Tag {
    @Tag static var scheduling: Self
    @Tag static var conflict: Self
    @Tag static var streak: Self
    @Tag static var dataLoader: Self
    @Tag static var integration: Self
    @Tag static var loadAdvisor: Self
}
```

- [ ] Commit:

```bash
git add Shared/Tests/InchSharedTests/TestTags.swift
git commit -m "feat: add loadAdvisor test tag"
```

---

### Task 2: Create `DailyLoadContext.swift` — input value types

**Files:**
- Create: `Shared/Sources/InchShared/Engine/DailyLoadContext.swift`

- [ ] Create the file:

```swift
import Foundation

/// Snapshot of today's training state passed to DailyLoadAdvisor.
/// Assembled by TodayViewModel from SwiftData — never constructed inside the advisor.
public struct DailyLoadContext: Sendable {
    /// Exercises fully completed so far today, one record per exercise.
    /// Empty until the user finishes their first exercise.
    public let completedToday: [CompletedExerciseRecord]

    /// Exercises due today that have not yet been completed.
    public let dueButNotDone: [PendingExerciseRecord]

    /// Exercises with a test day projected strictly within the next 48 hours
    /// (today's test days excluded — they are handled via completedToday or dueButNotDone).
    public let testDaysInNext48h: [(exerciseId: String, exerciseName: String, scheduledDate: Date)]

    /// Exercises completed yesterday. Used for the lookback penalty.
    public let yesterdayCompletions: [CompletedExerciseRecord]

    public init(
        completedToday: [CompletedExerciseRecord],
        dueButNotDone: [PendingExerciseRecord],
        testDaysInNext48h: [(exerciseId: String, exerciseName: String, scheduledDate: Date)],
        yesterdayCompletions: [CompletedExerciseRecord]
    ) {
        self.completedToday = completedToday
        self.dueButNotDone = dueButNotDone
        self.testDaysInNext48h = testDaysInNext48h
        self.yesterdayCompletions = yesterdayCompletions
    }
}

/// One completed exercise session (all sets for one exercise on a given day).
public struct CompletedExerciseRecord: Sendable {
    /// Matches ExerciseDefinition.exerciseId (e.g. "push_ups")
    public let exerciseId: String
    /// Display name for the exercise (e.g. "Push-Ups")
    public let exerciseName: String
    public let muscleGroup: MuscleGroup
    /// True if this session was a test day (all sets share the same isTest value)
    public let isTest: Bool
    /// True if the exercise's nextScheduledDate was before today when TodayViewModel loaded
    public let wasRescheduled: Bool

    public init(
        exerciseId: String,
        exerciseName: String,
        muscleGroup: MuscleGroup,
        isTest: Bool,
        wasRescheduled: Bool
    ) {
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.muscleGroup = muscleGroup
        self.isTest = isTest
        self.wasRescheduled = wasRescheduled
    }
}

/// An exercise due today that has not yet been completed.
public struct PendingExerciseRecord: Sendable {
    public let exerciseId: String
    public let exerciseName: String
    public let muscleGroup: MuscleGroup
    public let isTest: Bool

    public init(
        exerciseId: String,
        exerciseName: String,
        muscleGroup: MuscleGroup,
        isTest: Bool
    ) {
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.muscleGroup = muscleGroup
        self.isTest = isTest
    }
}
```

- [ ] Build to confirm it compiles. In the worktree root:

```bash
xcodebuild build \
  -scheme InchShared \
  -destination 'generic/platform=iOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] Commit:

```bash
git add Shared/Sources/InchShared/Engine/DailyLoadContext.swift
git commit -m "feat: add DailyLoadContext input types"
```

---

### Task 3: Create `LoadAdvisory.swift` — output value type

**Files:**
- Create: `Shared/Sources/InchShared/Engine/LoadAdvisory.swift`

This is the rich result returned by `DailyLoadAdvisor.recommend()`. The Today card reads whatever fields it needs for copy decisions.

- [ ] Create the file:

```swift
import Foundation

/// The advisor's recommendation for today's training.
/// Returned by DailyLoadAdvisor.recommend() once at least one exercise is completed.
/// The Today card owns all copy decisions — this struct provides the raw signals.
public struct LoadAdvisory: Sendable {
    /// Recommended total exercises for today. Always >= completedToday.count.
    public let recommendedCount: Int

    /// Muscle groups where completed exercises have consumed a high share of the daily budget
    /// (effective cost >= 3.0 for that group, accounting for multipliers).
    /// Example: squats on a test day (4.5 effective cost) → .lower is overloaded.
    public let overloadedGroups: [MuscleGroup]

    /// Muscle groups not yet worked today that would trigger the same-group compounding
    /// multiplier (×1.5) if exercised now, because their partner group has already been worked.
    /// Example: if squats (.lower) are done → .lowerPosterior (glute_bridges) is in cautionGroups.
    public let cautionGroups: [MuscleGroup]

    /// True if any active exercise has a test day scheduled within the next 48 hours.
    /// When true, the budget is reduced by 1 to encourage conservative volume.
    public let preTestTaperActive: Bool

    /// True if yesterday's training triggered the lookback reduction
    /// (a test day or 2+ high-cost exercises — squats or pull-ups — completed yesterday).
    public let lookbackPenaltyActive: Bool

    /// Fraction of the daily budget consumed so far (0.0–1.0+).
    /// Values above 1.0 mean the user has exceeded the recommended load.
    /// Useful for progress bar displays or colour-coding.
    public let budgetFraction: Double

    public init(
        recommendedCount: Int,
        overloadedGroups: [MuscleGroup],
        cautionGroups: [MuscleGroup],
        preTestTaperActive: Bool,
        lookbackPenaltyActive: Bool,
        budgetFraction: Double
    ) {
        self.recommendedCount = recommendedCount
        self.overloadedGroups = overloadedGroups
        self.cautionGroups = cautionGroups
        self.preTestTaperActive = preTestTaperActive
        self.lookbackPenaltyActive = lookbackPenaltyActive
        self.budgetFraction = budgetFraction
    }
}
```

- [ ] Build to confirm it compiles:

```bash
xcodebuild build \
  -scheme InchShared \
  -destination 'generic/platform=iOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] Commit:

```bash
git add Shared/Sources/InchShared/Engine/LoadAdvisory.swift
git commit -m "feat: add LoadAdvisory output type"
```

---

### Task 4: Write failing tests for `DailyLoadAdvisor`

**Files:**
- Create: `Shared/Tests/InchSharedTests/Engine/DailyLoadAdvisorTests.swift`

- [ ] Create the test directory if it doesn't exist:

```bash
mkdir -p Shared/Tests/InchSharedTests/Engine
```

- [ ] Create the test file. These tests define the contract before any implementation exists:

```swift
import Testing
import Foundation
@testable import InchShared

struct DailyLoadAdvisorTests {
    let advisor = DailyLoadAdvisor()

    // MARK: - Helpers

    func makeCompleted(
        _ exerciseId: String,
        muscleGroup: MuscleGroup = .upperPush,
        isTest: Bool = false,
        wasRescheduled: Bool = false
    ) -> CompletedExerciseRecord {
        CompletedExerciseRecord(
            exerciseId: exerciseId,
            exerciseName: exerciseId,
            muscleGroup: muscleGroup,
            isTest: isTest,
            wasRescheduled: wasRescheduled
        )
    }

    func makePending(
        _ exerciseId: String,
        muscleGroup: MuscleGroup = .upperPush,
        isTest: Bool = false
    ) -> PendingExerciseRecord {
        PendingExerciseRecord(
            exerciseId: exerciseId,
            exerciseName: exerciseId,
            muscleGroup: muscleGroup,
            isTest: isTest
        )
    }

    func makeContext(
        completed: [CompletedExerciseRecord] = [],
        pending: [PendingExerciseRecord] = [],
        testDaysInNext48h: [(exerciseId: String, exerciseName: String, scheduledDate: Date)] = [],
        yesterday: [CompletedExerciseRecord] = []
    ) -> DailyLoadContext {
        DailyLoadContext(
            completedToday: completed,
            dueButNotDone: pending,
            testDaysInNext48h: testDaysInNext48h,
            yesterdayCompletions: yesterday
        )
    }

    // MARK: - Nil when nothing completed

    @Test(.tags(.loadAdvisor))
    func returnsNilWhenNothingCompletedToday() {
        let context = makeContext(
            pending: [makePending("push_ups")]
        )
        #expect(advisor.recommend(context: context) == nil)
    }

    // MARK: - Base budget (no modifiers)

    @Test(.tags(.loadAdvisor))
    func freshDayWithCoreOnlySessionHasHighHeadroom() {
        // sit_ups (cost 1) + dead_bugs (cost 1) = 2 consumed of 10
        // 4 pending: avg cost ~2.5 → floor(8/2.5) = 3, capped at 4 → total 6
        let context = makeContext(
            completed: [
                makeCompleted("sit_ups", muscleGroup: .coreFlexion),
                makeCompleted("dead_bugs", muscleGroup: .coreStability)
            ],
            pending: [
                makePending("push_ups", muscleGroup: .upperPush),
                makePending("squats", muscleGroup: .lower),
                makePending("pull_ups", muscleGroup: .upperPull),
                makePending("glute_bridges", muscleGroup: .lowerPosterior)
            ]
        )
        let result = advisor.recommend(context: context)
        let count = try #require(result)
        // With 8 budget remaining and 4 medium/high cost exercises, should recommend all 6
        #expect(count == 6)
    }

    @Test(.tags(.loadAdvisor))
    func twoHighCostExercisesConsumesMostBudget() {
        // squats (3) + pull_ups (3) = 6 consumed of 10 → 4 remaining
        // 2 pending at cost 1 each → floor(4/1) = 4, capped at 2 → total 4
        let context = makeContext(
            completed: [
                makeCompleted("squats", muscleGroup: .lower),
                makeCompleted("pull_ups", muscleGroup: .upperPull)
            ],
            pending: [
                makePending("sit_ups", muscleGroup: .coreFlexion),
                makePending("dead_bugs", muscleGroup: .coreStability)
            ]
        )
        let result = advisor.recommend(context: context)
        #expect(result?.recommendedCount == 4)
    }

    @Test(.tags(.loadAdvisor))
    func allSixExercisesExceedsBudget() {
        // All 6 completed: 3+3+2+2+1+1 = 12 > 10 → remainingBudget = 0 → N_more = 0
        let context = makeContext(
            completed: [
                makeCompleted("squats", muscleGroup: .lower),
                makeCompleted("pull_ups", muscleGroup: .upperPull),
                makeCompleted("push_ups", muscleGroup: .upperPush),
                makeCompleted("glute_bridges", muscleGroup: .lowerPosterior),
                makeCompleted("sit_ups", muscleGroup: .coreFlexion),
                makeCompleted("dead_bugs", muscleGroup: .coreStability)
            ]
        )
        let result = advisor.recommend(context: context)
        // recommendedCount always >= completedToday.count, so = 6
        #expect(result?.recommendedCount == 6)
    }

    // MARK: - Test day multiplier (×1.5)

    @Test(.tags(.loadAdvisor))
    func testDayCompletedCostsMoreThanRegular() {
        // push_ups test: 2 × 1.5 = 3.0 consumed (vs 2.0 without test)
        let testContext = makeContext(
            completed: [makeCompleted("push_ups", muscleGroup: .upperPush, isTest: true)],
            pending: [makePending("sit_ups", muscleGroup: .coreFlexion)]
        )
        let regularContext = makeContext(
            completed: [makeCompleted("push_ups", muscleGroup: .upperPush, isTest: false)],
            pending: [makePending("sit_ups", muscleGroup: .coreFlexion)]
        )
        let testResult = try #require(advisor.recommend(context: testContext))
        let regularResult = try #require(advisor.recommend(context: regularContext))
        // Test day uses more budget → fewer or equal exercises recommended
        #expect(testResult.recommendedCount <= regularResult.recommendedCount)
    }

    @Test(.tags(.loadAdvisor))
    func squatsTestDayEffectiveCostIs4Point5() {
        // squats test: 3 × 1.5 = 4.5 consumed of 10 → 5.5 remaining
        // 1 pending at cost 1 → floor(5.5/1) = 5, capped at 1 → total 2
        let context = makeContext(
            completed: [makeCompleted("squats", muscleGroup: .lower, isTest: true)],
            pending: [makePending("sit_ups", muscleGroup: .coreFlexion)]
        )
        #expect(advisor.recommend(context: context)?.recommendedCount == 2)
    }

    // MARK: - Same-group compounding (×1.5 on second exercise)

    @Test(.tags(.loadAdvisor))
    func squatsAndGluteBridgesBothCountedWithCompounding() {
        // squats (3) + glute_bridges with compounding (2 × 1.5 = 3) = 6 consumed
        // 2 pending core at cost 1 → floor(4/1) = 4, capped at 2 → total 4
        let context = makeContext(
            completed: [
                makeCompleted("squats", muscleGroup: .lower),
                makeCompleted("glute_bridges", muscleGroup: .lowerPosterior)
            ],
            pending: [
                makePending("sit_ups", muscleGroup: .coreFlexion),
                makePending("dead_bugs", muscleGroup: .coreStability)
            ]
        )
        #expect(advisor.recommend(context: context)?.recommendedCount == 4)
    }

    @Test(.tags(.loadAdvisor))
    func coreExercisesDoNotCompoundEachOther() {
        // sit_ups (1) + dead_bugs (1) = 2 consumed — NO compounding for core pair
        let context = makeContext(
            completed: [
                makeCompleted("sit_ups", muscleGroup: .coreFlexion),
                makeCompleted("dead_bugs", muscleGroup: .coreStability)
            ],
            pending: [makePending("push_ups", muscleGroup: .upperPush)]
        )
        // Budget used = 2, remaining = 8, 1 pending at cost 2 → total 3
        #expect(advisor.recommend(context: context)?.recommendedCount == 3)
    }

    @Test(.tags(.loadAdvisor))
    func sameGroupOrderDoesNotMatter() {
        // Both orderings should consume the same total budget
        let gluteFirst = makeContext(
            completed: [
                makeCompleted("glute_bridges", muscleGroup: .lowerPosterior),
                makeCompleted("squats", muscleGroup: .lower)
            ],
            pending: [makePending("sit_ups", muscleGroup: .coreFlexion)]
        )
        let squatsFirst = makeContext(
            completed: [
                makeCompleted("squats", muscleGroup: .lower),
                makeCompleted("glute_bridges", muscleGroup: .lowerPosterior)
            ],
            pending: [makePending("sit_ups", muscleGroup: .coreFlexion)]
        )
        let r1 = advisor.recommend(context: gluteFirst)
        let r2 = advisor.recommend(context: squatsFirst)
        #expect(r1?.recommendedCount == r2?.recommendedCount)
    }

    // MARK: - Rescheduled exercise (×1.25)

    @Test(.tags(.loadAdvisor))
    func rescheduledExerciseCostsMore() {
        let rescheduled = makeContext(
            completed: [makeCompleted("push_ups", muscleGroup: .upperPush, wasRescheduled: true)],
            pending: [makePending("sit_ups", muscleGroup: .coreFlexion)]
        )
        let onSchedule = makeContext(
            completed: [makeCompleted("push_ups", muscleGroup: .upperPush, wasRescheduled: false)],
            pending: [makePending("sit_ups", muscleGroup: .coreFlexion)]
        )
        let rescheduledResult = try #require(advisor.recommend(context: rescheduled))
        let onScheduleResult = try #require(advisor.recommend(context: onSchedule))
        #expect(rescheduledResult.recommendedCount <= onScheduleResult.recommendedCount)
    }

    // MARK: - Budget-level reductions

    @Test(.tags(.loadAdvisor))
    func preTestTaperReducesBudgetAndSetsFlag() {
        let tomorrow = Date.now.addingTimeInterval(24 * 3600)
        let withTaper = makeContext(
            completed: [makeCompleted("push_ups", muscleGroup: .upperPush)],
            pending: [makePending("sit_ups", muscleGroup: .coreFlexion)],
            testDaysInNext48h: [("pull_ups", "Pull-Ups", tomorrow)]
        )
        let withoutTaper = makeContext(
            completed: [makeCompleted("push_ups", muscleGroup: .upperPush)],
            pending: [makePending("sit_ups", muscleGroup: .coreFlexion)]
        )
        let taperResult = try #require(advisor.recommend(context: withTaper))
        let noTaperResult = try #require(advisor.recommend(context: withoutTaper))
        #expect(taperResult.preTestTaperActive == true)
        #expect(noTaperResult.preTestTaperActive == false)
        #expect(taperResult.recommendedCount <= noTaperResult.recommendedCount)
    }

    @Test(.tags(.loadAdvisor))
    func lookbackPenaltyFromYesterdaysTestSetsFlag() {
        let withPenalty = makeContext(
            completed: [makeCompleted("push_ups", muscleGroup: .upperPush)],
            pending: [makePending("sit_ups", muscleGroup: .coreFlexion)],
            yesterday: [makeCompleted("squats", muscleGroup: .lower, isTest: true)]
        )
        let withoutPenalty = makeContext(
            completed: [makeCompleted("push_ups", muscleGroup: .upperPush)],
            pending: [makePending("sit_ups", muscleGroup: .coreFlexion)]
        )
        let penaltyResult = try #require(advisor.recommend(context: withPenalty))
        let noPenaltyResult = try #require(advisor.recommend(context: withoutPenalty))
        #expect(penaltyResult.lookbackPenaltyActive == true)
        #expect(noPenaltyResult.lookbackPenaltyActive == false)
        #expect(penaltyResult.recommendedCount <= noPenaltyResult.recommendedCount)
    }

    @Test(.tags(.loadAdvisor))
    func lookbackPenaltyFromTwoHighCostYesterdayExercises() {
        let context = makeContext(
            completed: [makeCompleted("push_ups", muscleGroup: .upperPush)],
            pending: [makePending("sit_ups", muscleGroup: .coreFlexion)],
            yesterday: [
                makeCompleted("squats", muscleGroup: .lower),
                makeCompleted("pull_ups", muscleGroup: .upperPull)
            ]
        )
        let result = try #require(advisor.recommend(context: context))
        #expect(result.lookbackPenaltyActive == true)
    }

    // MARK: - Overloaded and caution groups

    @Test(.tags(.loadAdvisor))
    func squatsTestDayMarksLowerGroupOverloaded() {
        // squats test: 3 × 1.5 = 4.5 ≥ 3.0 threshold → .lower is overloaded
        let context = makeContext(
            completed: [makeCompleted("squats", muscleGroup: .lower, isTest: true)]
        )
        let result = try #require(advisor.recommend(context: context))
        #expect(result.overloadedGroups.contains(.lower))
    }

    @Test(.tags(.loadAdvisor))
    func lowCostExerciseDoesNotOverloadGroup() {
        // sit_ups: cost 1.0 < 3.0 threshold → .coreFlexion is NOT overloaded
        let context = makeContext(
            completed: [makeCompleted("sit_ups", muscleGroup: .coreFlexion)]
        )
        let result = try #require(advisor.recommend(context: context))
        #expect(result.overloadedGroups.contains(.coreFlexion) == false)
    }

    @Test(.tags(.loadAdvisor))
    func squatsDoneCreatesCautionGroupForLowerPosterior() {
        // squats (.lower) worked → .lowerPosterior should appear in cautionGroups
        let context = makeContext(
            completed: [makeCompleted("squats", muscleGroup: .lower)],
            pending: [makePending("glute_bridges", muscleGroup: .lowerPosterior)]
        )
        let result = try #require(advisor.recommend(context: context))
        #expect(result.cautionGroups.contains(.lowerPosterior))
    }

    @Test(.tags(.loadAdvisor))
    func bothLowerGroupsWorkedClearsAllCautionGroups() {
        // When both partners are already worked, neither is a "caution" (they're done)
        let context = makeContext(
            completed: [
                makeCompleted("squats", muscleGroup: .lower),
                makeCompleted("glute_bridges", muscleGroup: .lowerPosterior)
            ]
        )
        let result = try #require(advisor.recommend(context: context))
        // Both groups have been worked — neither is a pending caution
        #expect(result.cautionGroups.contains(.lower) == false)
        #expect(result.cautionGroups.contains(.lowerPosterior) == false)
    }

    @Test(.tags(.loadAdvisor))
    func coreGroupsNeverAppearInCautionGroups() {
        // Core exercises have no compounding partners → never in cautionGroups
        let context = makeContext(
            completed: [makeCompleted("sit_ups", muscleGroup: .coreFlexion)]
        )
        let result = try #require(advisor.recommend(context: context))
        #expect(result.cautionGroups.contains(.coreStability) == false)
        #expect(result.cautionGroups.contains(.coreFlexion) == false)
    }

    // MARK: - Budget fraction

    @Test(.tags(.loadAdvisor))
    func budgetFractionReflectsConsumedLoad() {
        // push_ups (2) of budget 10 → fraction = 0.2
        let context = makeContext(
            completed: [makeCompleted("push_ups", muscleGroup: .upperPush)]
        )
        let result = try #require(advisor.recommend(context: context))
        #expect(abs(result.budgetFraction - 0.2) < 0.01)
    }

    @Test(.tags(.loadAdvisor))
    func budgetFractionCanExceedOne() {
        // All 6: 3+3+2+2+1+1 = 12 of budget 10 → fraction = 1.2
        let context = makeContext(
            completed: [
                makeCompleted("squats", muscleGroup: .lower),
                makeCompleted("pull_ups", muscleGroup: .upperPull),
                makeCompleted("push_ups", muscleGroup: .upperPush),
                makeCompleted("glute_bridges", muscleGroup: .lowerPosterior),
                makeCompleted("sit_ups", muscleGroup: .coreFlexion),
                makeCompleted("dead_bugs", muscleGroup: .coreStability)
            ]
        )
        let result = try #require(advisor.recommend(context: context))
        #expect(result.budgetFraction > 1.0)
    }

    // MARK: - Boundary conditions

    @Test(.tags(.loadAdvisor))
    func recommendedCountNeverLessThanCompletedCount() {
        // Force budget exhaustion
        let tomorrow = Date.now.addingTimeInterval(24 * 3600)
        let context = makeContext(
            completed: [
                makeCompleted("squats", muscleGroup: .lower, isTest: true),
                makeCompleted("glute_bridges", muscleGroup: .lowerPosterior, isTest: true)
            ],
            pending: [makePending("push_ups", muscleGroup: .upperPush)],
            testDaysInNext48h: [("pull_ups", "Pull-Ups", tomorrow)]
        )
        let result = try #require(advisor.recommend(context: context))
        #expect(result.recommendedCount >= 2)  // >= completedToday.count
    }

    @Test(.tags(.loadAdvisor))
    func noPendingExercisesReturnsSameAsCompleted() {
        let context = makeContext(
            completed: [makeCompleted("push_ups", muscleGroup: .upperPush)]
        )
        #expect(advisor.recommend(context: context)?.recommendedCount == 1)
    }

    @Test(.tags(.loadAdvisor))
    func emptyContextReturnsNil() {
        let context = makeContext()
        #expect(advisor.recommend(context: context) == nil)
    }
}
```

- [ ] Build tests to confirm they fail cleanly (type not found, not logic errors):

```bash
xcodebuild test \
  -scheme InchShared \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:InchSharedTests/DailyLoadAdvisorTests \
  2>&1 | grep -E "error:|BUILD FAILED|BUILD SUCCEEDED"
```

Expected: `BUILD FAILED` with "cannot find type 'DailyLoadAdvisor' in scope"

- [ ] Commit tests:

```bash
git add Shared/Tests/InchSharedTests/Engine/DailyLoadAdvisorTests.swift
git commit -m "test: add DailyLoadAdvisor tests (failing)"
```

---

### Task 5: Implement `DailyLoadAdvisor`

**Files:**
- Create: `Shared/Sources/InchShared/Engine/DailyLoadAdvisor.swift`

- [ ] Create the implementation:

```swift
import Foundation

/// Pure-logic engine that recommends how many total exercises a user should
/// complete today based on load, muscle group fatigue, test day costs,
/// upcoming test days, and yesterday's training.
///
/// Returns nil if no exercises have been completed today — there is nothing
/// to advise on yet. Returns a LoadAdvisory once at least one exercise is done.
public struct DailyLoadAdvisor: Sendable {

    // MARK: - Constants

    /// Daily load budget. All 6 exercises at base cost sum to 12, so a full
    /// day slightly exceeds the budget (correctly flagging it as elevated-risk).
    private static let dailyBudgetCeiling: Double = 10

    /// Base fatigue cost per exercise, grounded in rest-timer defaults
    /// and recovery research. Squats/pull-ups: 72h recovery (High=3).
    /// Push-ups/glute-bridges: 48h (Medium=2). Core: 24h (Low=1).
    private static let baseCosts: [String: Double] = [
        "squats":        3,
        "pull_ups":      3,
        "push_ups":      2,
        "glute_bridges": 2,
        "sit_ups":       1,
        "dead_bugs":     1
    ]

    /// Default cost for an unknown exercise (medium tier).
    private static let defaultCost: Double = 2

    /// Overload threshold. A muscle group is considered "overloaded" when the
    /// effective cost for that group's exercises meets or exceeds this value.
    private static let overloadThreshold: Double = 3.0

    /// Same-group compounding pairs. The second exercise in a pair costs ×1.5
    /// because the shared primary movers (glutes/hip extensors for the lower pair)
    /// accumulate fatigue super-additively. Core exercises are excluded — they
    /// target different movement patterns and carry negligible systemic cost.
    private static let compoundingPartners: [MuscleGroup: MuscleGroup] = [
        .lower:          .lowerPosterior,
        .lowerPosterior: .lower
    ]

    // MARK: - Public API

    public init() {}

    /// Recommend the total number of exercises for today.
    /// - Returns: nil if completedToday is empty (no session started).
    ///            A LoadAdvisory with recommendedCount >= completedToday.count otherwise.
    public func recommend(context: DailyLoadContext) -> LoadAdvisory? {
        guard !context.completedToday.isEmpty else { return nil }

        let preTestTaperActive = !context.testDaysInNext48h.isEmpty
        let lookbackPenaltyActive = lookbackPenaltyTriggered(context: context)

        let effectiveBudget = Self.dailyBudgetCeiling
            - (preTestTaperActive ? 1.0 : 0.0)
            - (lookbackPenaltyActive ? 1.0 : 0.0)

        // Compute per-exercise costs, tracking per-group totals for overloadedGroups
        let completedMuscleGroups = Set(context.completedToday.map(\.muscleGroup))
        var costByGroup: [MuscleGroup: Double] = [:]
        var consumed: Double = 0

        for record in context.completedToday {
            let cost = effectiveCost(
                record: record,
                alreadyWorkedGroups: completedMuscleGroups.subtracting([record.muscleGroup])
            )
            consumed += cost
            costByGroup[record.muscleGroup, default: 0] += cost
        }

        let overloadedGroups = costByGroup
            .filter { $0.value >= Self.overloadThreshold }
            .map(\.key)
            .sorted { $0.rawValue < $1.rawValue }

        // Caution groups: not-yet-worked groups whose compounding partner was already worked
        let cautionGroups = Self.compoundingPartners
            .filter { group, partner in
                completedMuscleGroups.contains(partner) && !completedMuscleGroups.contains(group)
            }
            .map(\.key)
            .sorted { $0.rawValue < $1.rawValue }

        let budgetFraction = consumed / effectiveBudget
        let remaining = max(0, effectiveBudget - consumed)

        let avgRemainingCost = averageCost(of: context.dueButNotDone)
        let nMore: Int
        if context.dueButNotDone.isEmpty {
            nMore = 0
        } else {
            nMore = min(
                Int(floor(remaining / avgRemainingCost)),
                context.dueButNotDone.count
            )
        }

        return LoadAdvisory(
            recommendedCount: context.completedToday.count + nMore,
            overloadedGroups: overloadedGroups,
            cautionGroups: cautionGroups,
            preTestTaperActive: preTestTaperActive,
            lookbackPenaltyActive: lookbackPenaltyActive,
            budgetFraction: budgetFraction
        )
    }

    // MARK: - Cost calculation

    private func effectiveCost(
        record: CompletedExerciseRecord,
        alreadyWorkedGroups: Set<MuscleGroup>
    ) -> Double {
        var cost = Self.baseCosts[record.exerciseId] ?? Self.defaultCost

        // Test day: ×1.5 (training to failure spikes local and neural fatigue)
        if record.isTest { cost *= 1.5 }

        // Same-group compounding: ×1.5 if the partner group was already worked today
        if let partner = Self.compoundingPartners[record.muscleGroup],
           alreadyWorkedGroups.contains(partner) {
            cost *= 1.5
        }

        // Rescheduled: ×1.25 (ACWR spike — load above this week's conditioned baseline)
        if record.wasRescheduled { cost *= 1.25 }

        return cost
    }

    // MARK: - Budget-level reductions

    private func lookbackPenaltyTriggered(context: DailyLoadContext) -> Bool {
        let hadTestDay = context.yesterdayCompletions.contains(where: \.isTest)
        let highCostIds: Set<String> = ["squats", "pull_ups"]
        let highCostCount = context.yesterdayCompletions.filter {
            highCostIds.contains($0.exerciseId)
        }.count
        return hadTestDay || highCostCount >= 2
    }

    // MARK: - Helpers

    private func averageCost(of records: [PendingExerciseRecord]) -> Double {
        guard !records.isEmpty else { return 2.0 }
        let total = records.reduce(0.0) { $0 + (Self.baseCosts[$1.exerciseId] ?? Self.defaultCost) }
        return total / Double(records.count)
    }
}
```

- [ ] Run the tests:

```bash
xcodebuild test \
  -scheme InchShared \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:InchSharedTests/DailyLoadAdvisorTests \
  2>&1 | grep -E "Test.*passed|Test.*failed|BUILD"
```

Expected: All tests pass. If any fail, fix the implementation before proceeding.

- [ ] Run the full shared test suite to check for regressions:

```bash
xcodebuild test \
  -scheme InchShared \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  2>&1 | grep -E "Test Suite.*passed|failed|BUILD"
```

Expected: All existing tests still pass.

- [ ] Commit:

```bash
git add Shared/Sources/InchShared/Engine/DailyLoadAdvisor.swift
git commit -m "feat: implement DailyLoadAdvisor engine"
```

---

## Chunk 2: TodayViewModel integration

### Task 6: Wire advisor into `TodayViewModel`

**Files:**
- Modify: `inch/inch/Features/Today/TodayViewModel.swift`

`TodayViewModel` already fetches `ExerciseEnrolment` and `CompletedSet` records in `loadToday()`. We add three things:
1. `rescheduledExerciseIds` — captured at load time before any completions can overwrite `nextScheduledDate`
2. `advisory: LoadAdvisory?` — the advisor output exposed to the view
3. `buildAndRunAdvisor(context:all:todaySets:today:)` — assembles `DailyLoadContext` and calls `DailyLoadAdvisor`

The full current content of `TodayViewModel.swift` is:

```swift
import SwiftData
import Foundation
import InchShared

@Observable
final class TodayViewModel {
    var dueExercises: [ExerciseEnrolment] = []
    var completedTodayIds: Set<String> = []
    var isRestDay: Bool = false
    var conflictWarnings: [String: String] = [:]
    var nextTrainingDate: Date? = nil
    var nextTrainingCount: Int = 0
    private let detector = ConflictDetector()

    func loadToday(context: ModelContext, showWarnings: Bool = true) {
        let today = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
        let descriptor = FetchDescriptor<ExerciseEnrolment>(
            predicate: #Predicate { $0.isActive }
        )
        let all = (try? context.fetch(descriptor)) ?? []

        // Exercises due today (scheduled today or overdue)
        let dueToday = all.filter { enrolment in
            guard let scheduled = enrolment.nextScheduledDate else { return false }
            return Calendar.current.startOfDay(for: scheduled) <= today
        }

        // Exercises completed today (may have advanced nextScheduledDate)
        let setsDescriptor = FetchDescriptor<CompletedSet>(
            predicate: #Predicate { $0.sessionDate >= today && $0.sessionDate < tomorrow }
        )
        let todaySets = (try? context.fetch(setsDescriptor)) ?? []

        // Group today's sets by exercise ID
        let setsByExercise = Dictionary(grouping: todaySets, by: \.exerciseId)

        // An exercise is fully complete when all prescribed sets are done
        let fullyCompletedIds = Set(all.compactMap { enrolment -> String? in
            guard let id = enrolment.exerciseDefinition?.exerciseId else { return nil }
            let completedCount = setsByExercise[id]?.count ?? 0
            let prescribedCount = currentPrescription(for: enrolment)?.sets.count ?? 0
            guard prescribedCount > 0, completedCount >= prescribedCount else { return nil }
            return id
        })

        completedTodayIds = fullyCompletedIds

        // Include completed-today exercises that are no longer in the due list
        let completedEnrolments = all.filter { enrolment in
            guard let id = enrolment.exerciseDefinition?.exerciseId else { return false }
            return fullyCompletedIds.contains(id) && !dueToday.contains(where: { $0.persistentModelID == enrolment.persistentModelID })
        }

        dueExercises = dueToday + completedEnrolments
        isRestDay = dueExercises.isEmpty

        if isRestDay {
            computeNextTraining(from: all, after: today)
        }

        if showWarnings {
            detectConflictsForToday()
        } else {
            conflictWarnings = [:]
        }
        resetStreakForMissedDayIfNeeded(context: context, today: today)
    }

    private func computeNextTraining(from all: [ExerciseEnrolment], after today: Date) {
        let futureDates = all.compactMap(\.nextScheduledDate)
            .map { Calendar.current.startOfDay(for: $0) }
            .filter { $0 > today }
        guard let nearest = futureDates.min() else { return }
        nextTrainingDate = nearest
        nextTrainingCount = all.filter { enrolment in
            guard let d = enrolment.nextScheduledDate else { return false }
            return Calendar.current.startOfDay(for: d) == nearest
        }.count
    }

    private func detectConflictsForToday() {
        conflictWarnings = [:]
        let sessions: [ProjectedSession] = dueExercises.compactMap { enrolment in
            guard let def = enrolment.exerciseDefinition else { return nil }
            let isTest = currentPrescription(for: enrolment)?.isTest ?? false
            return ProjectedSession(
                exerciseId: def.exerciseId,
                muscleGroup: def.muscleGroup,
                isTest: isTest,
                date: .now,
                enrolmentId: def.exerciseId
            )
        }
        let conflicts = detector.detectConflicts(in: sessions)
        for conflict in conflicts {
            switch conflict {
            case .doubleTest(_, let ids):
                for id in ids {
                    conflictWarnings[id] = "Two test days scheduled today"
                }
            case .testWithSameGroupTraining(_, _, let trainingId):
                conflictWarnings[trainingId] = "Same muscle group as today's test"
            }
        }
    }

    private func resetStreakForMissedDayIfNeeded(context: ModelContext, today: Date) {
        guard !isRestDay else { return }
        let streaks = (try? context.fetch(FetchDescriptor<StreakState>())) ?? []
        guard let streakState = streaks.first, streakState.currentStreak > 0 else { return }
        guard let lastActive = streakState.lastActiveDate else { return }

        let lastDay = Calendar.current.startOfDay(for: lastActive)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today
        if lastDay < Calendar.current.startOfDay(for: yesterday) {
            streakState.currentStreak = 0
            try? context.save()
        }
    }

    func currentPrescription(for enrolment: ExerciseEnrolment) -> DayPrescription? {
        enrolment.exerciseDefinition?
            .levels?
            .first(where: { $0.level == enrolment.currentLevel })?
            .days?
            .first(where: { $0.dayNumber == enrolment.currentDay })
    }
}
```

- [ ] Replace the entire file with the updated version below. Read the current file first to confirm it matches the above before making changes.

```swift
import SwiftData
import Foundation
import InchShared

@Observable
final class TodayViewModel {
    var dueExercises: [ExerciseEnrolment] = []
    var completedTodayIds: Set<String> = []
    var isRestDay: Bool = false
    var conflictWarnings: [String: String] = [:]
    var nextTrainingDate: Date? = nil
    var nextTrainingCount: Int = 0
    /// Advisor recommendation for today's training load. Nil until the first exercise is completed.
    var advisory: LoadAdvisory? = nil
    private let detector = ConflictDetector()
    /// Exercise IDs whose nextScheduledDate was before today when loadToday() ran.
    /// Captured each load call so rescheduled status is always current.
    private var rescheduledExerciseIds: Set<String> = []

    func loadToday(context: ModelContext, showWarnings: Bool = true) {
        let today = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
        let descriptor = FetchDescriptor<ExerciseEnrolment>(
            predicate: #Predicate { $0.isActive }
        )
        let all = (try? context.fetch(descriptor)) ?? []

        // Exercises due today (scheduled today or overdue)
        let dueToday = all.filter { enrolment in
            guard let scheduled = enrolment.nextScheduledDate else { return false }
            return Calendar.current.startOfDay(for: scheduled) <= today
        }

        // Exercises completed today (may have advanced nextScheduledDate)
        let setsDescriptor = FetchDescriptor<CompletedSet>(
            predicate: #Predicate { $0.sessionDate >= today && $0.sessionDate < tomorrow }
        )
        let todaySets = (try? context.fetch(setsDescriptor)) ?? []

        // Group today's sets by exercise ID
        let setsByExercise = Dictionary(grouping: todaySets, by: \.exerciseId)

        // An exercise is fully complete when all prescribed sets are done
        let fullyCompletedIds = Set(all.compactMap { enrolment -> String? in
            guard let id = enrolment.exerciseDefinition?.exerciseId else { return nil }
            let completedCount = setsByExercise[id]?.count ?? 0
            let prescribedCount = currentPrescription(for: enrolment)?.sets.count ?? 0
            guard prescribedCount > 0, completedCount >= prescribedCount else { return nil }
            return id
        })

        completedTodayIds = fullyCompletedIds

        // Include completed-today exercises that are no longer in the due list
        let completedEnrolments = all.filter { enrolment in
            guard let id = enrolment.exerciseDefinition?.exerciseId else { return false }
            return fullyCompletedIds.contains(id) && !dueToday.contains(where: { $0.persistentModelID == enrolment.persistentModelID })
        }

        dueExercises = dueToday + completedEnrolments
        isRestDay = dueExercises.isEmpty

        if isRestDay {
            computeNextTraining(from: all, after: today)
        }

        if showWarnings {
            detectConflictsForToday()
        } else {
            conflictWarnings = [:]
        }
        resetStreakForMissedDayIfNeeded(context: context, today: today)
        buildAndRunAdvisor(context: context, all: all, todaySets: todaySets, today: today)
    }

    private func computeNextTraining(from all: [ExerciseEnrolment], after today: Date) {
        let futureDates = all.compactMap(\.nextScheduledDate)
            .map { Calendar.current.startOfDay(for: $0) }
            .filter { $0 > today }
        guard let nearest = futureDates.min() else { return }
        nextTrainingDate = nearest
        nextTrainingCount = all.filter { enrolment in
            guard let d = enrolment.nextScheduledDate else { return false }
            return Calendar.current.startOfDay(for: d) == nearest
        }.count
    }

    private func detectConflictsForToday() {
        conflictWarnings = [:]
        let sessions: [ProjectedSession] = dueExercises.compactMap { enrolment in
            guard let def = enrolment.exerciseDefinition else { return nil }
            let isTest = currentPrescription(for: enrolment)?.isTest ?? false
            return ProjectedSession(
                exerciseId: def.exerciseId,
                muscleGroup: def.muscleGroup,
                isTest: isTest,
                date: .now,
                enrolmentId: def.exerciseId
            )
        }
        let conflicts = detector.detectConflicts(in: sessions)
        for conflict in conflicts {
            switch conflict {
            case .doubleTest(_, let ids):
                for id in ids {
                    conflictWarnings[id] = "Two test days scheduled today"
                }
            case .testWithSameGroupTraining(_, _, let trainingId):
                conflictWarnings[trainingId] = "Same muscle group as today's test"
            }
        }
    }

    private func resetStreakForMissedDayIfNeeded(context: ModelContext, today: Date) {
        guard !isRestDay else { return }
        let streaks = (try? context.fetch(FetchDescriptor<StreakState>())) ?? []
        guard let streakState = streaks.first, streakState.currentStreak > 0 else { return }
        guard let lastActive = streakState.lastActiveDate else { return }

        let lastDay = Calendar.current.startOfDay(for: lastActive)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today
        if lastDay < Calendar.current.startOfDay(for: yesterday) {
            streakState.currentStreak = 0
            try? context.save()
        }
    }

    func currentPrescription(for enrolment: ExerciseEnrolment) -> DayPrescription? {
        enrolment.exerciseDefinition?
            .levels?
            .first(where: { $0.level == enrolment.currentLevel })?
            .days?
            .first(where: { $0.dayNumber == enrolment.currentDay })
    }

    // MARK: - Daily Load Advisor

    private func buildAndRunAdvisor(
        context: ModelContext,
        all: [ExerciseEnrolment],
        todaySets: [CompletedSet],
        today: Date
    ) {
        let startOfToday = Calendar.current.startOfDay(for: .now)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
        let endOfYesterday = startOfToday

        // Step 1: Capture rescheduled status.
        // Any active enrolment whose nextScheduledDate is strictly before today
        // was overdue when this load call ran.
        rescheduledExerciseIds = Set(all.compactMap { enrolment -> String? in
            guard let scheduled = enrolment.nextScheduledDate,
                  Calendar.current.startOfDay(for: scheduled) < startOfToday,
                  let id = enrolment.exerciseDefinition?.exerciseId else { return nil }
            return id
        })

        // Step 2: Build completedToday records (one per exercise, collapsed from sets)
        let setsByExercise = Dictionary(grouping: todaySets, by: \.exerciseId)
        let completedToday: [CompletedExerciseRecord] = setsByExercise.compactMap { exerciseId, sets in
            guard let enrolment = all.first(where: { $0.exerciseDefinition?.exerciseId == exerciseId }),
                  let definition = enrolment.exerciseDefinition,
                  let anySet = sets.first else { return nil }
            return CompletedExerciseRecord(
                exerciseId: exerciseId,
                exerciseName: definition.name,
                muscleGroup: definition.muscleGroup,
                isTest: anySet.isTest,
                wasRescheduled: rescheduledExerciseIds.contains(exerciseId)
            )
        }

        guard !completedToday.isEmpty else {
            advisory = nil
            return
        }

        // Step 3: Build dueButNotDone
        let completedIds = Set(completedToday.map(\.exerciseId))
        let dueButNotDone: [PendingExerciseRecord] = all.compactMap { enrolment in
            guard enrolment.isActive,
                  let scheduled = enrolment.nextScheduledDate,
                  Calendar.current.startOfDay(for: scheduled) <= startOfToday,
                  let definition = enrolment.exerciseDefinition,
                  !completedIds.contains(definition.exerciseId) else { return nil }
            let isTest = currentPrescription(for: enrolment)?.isTest ?? false
            return PendingExerciseRecord(
                exerciseId: definition.exerciseId,
                exerciseName: definition.name,
                muscleGroup: definition.muscleGroup,
                isTest: isTest
            )
        }

        // Step 4: Build testDaysInNext48h using SchedulingEngine.projectSchedule()
        let engine = SchedulingEngine()
        let fortyEightHoursFromNow = Date.now.addingTimeInterval(48 * 3600)
        var testDaysInNext48h: [(exerciseId: String, exerciseName: String, scheduledDate: Date)] = []

        for enrolment in all where enrolment.isActive {
            guard let definition = enrolment.exerciseDefinition,
                  let levelDef = definition.levels?.first(where: { $0.level == enrolment.currentLevel }),
                  let rawStartDate = enrolment.nextScheduledDate else { continue }
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
            if let upcoming = projected.first(where: {
                $0.isTest && $0.scheduledDate > startOfToday && $0.scheduledDate <= fortyEightHoursFromNow
            }) {
                testDaysInNext48h.append((
                    exerciseId: definition.exerciseId,
                    exerciseName: definition.name,
                    scheduledDate: upcoming.scheduledDate
                ))
            }
        }

        // Step 5: Build yesterdayCompletions
        let yesterdayDescriptor = FetchDescriptor<CompletedSet>(
            predicate: #Predicate { $0.sessionDate >= yesterday && $0.sessionDate < endOfYesterday }
        )
        let yesterdaySets = (try? context.fetch(yesterdayDescriptor)) ?? []
        let yesterdayByExercise = Dictionary(grouping: yesterdaySets, by: \.exerciseId)
        let yesterdayCompletions: [CompletedExerciseRecord] = yesterdayByExercise.compactMap { exerciseId, sets in
            guard let enrolment = all.first(where: { $0.exerciseDefinition?.exerciseId == exerciseId }),
                  let definition = enrolment.exerciseDefinition,
                  let anySet = sets.first else { return nil }
            return CompletedExerciseRecord(
                exerciseId: exerciseId,
                exerciseName: definition.name,
                muscleGroup: definition.muscleGroup,
                isTest: anySet.isTest,
                wasRescheduled: false
            )
        }

        // Step 6: Run advisor
        let loadContext = DailyLoadContext(
            completedToday: completedToday,
            dueButNotDone: dueButNotDone,
            testDaysInNext48h: testDaysInNext48h,
            yesterdayCompletions: yesterdayCompletions
        )
        advisory = DailyLoadAdvisor().recommend(context: loadContext)
    }
}
```

- [ ] Build the iOS target to confirm it compiles:

```bash
xcodebuild build \
  -scheme inch \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] Run the full test suite one more time:

```bash
xcodebuild test \
  -scheme InchShared \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  2>&1 | grep -E "Test Suite.*passed|failed|BUILD"
```

Expected: All tests pass.

- [ ] Commit:

```bash
git add inch/inch/Features/Today/TodayViewModel.swift
git commit -m "feat: wire DailyLoadAdvisor into TodayViewModel"
```

---

## Final: push branch

- [ ] Push the feature branch:

```bash
git push -u origin feature/daily-load-advisor
```

`TodayViewModel.advisory: LoadAdvisory?` is now available for the Today card to read.
The card implementation (copy, layout, show/hide logic) is handled separately.
