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
        #expect(count.recommendedCount == 6)
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
