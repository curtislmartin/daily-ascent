import Testing
import Foundation
@testable import InchShared

struct LoadAdvisoryCopyTests {

    // MARK: - Nil fallback

    @Test(.tags(.loadAdvisor))
    func nilAdvisoryCompletedOneReturnsFallback() {
        let copy = LoadAdvisoryCopy.copy(completedCount: 1, advisory: nil)
        #expect(copy == "Good start — keep going if you feel up to it.")
    }

    @Test(.tags(.loadAdvisor))
    func nilAdvisoryCompletedTwoReturnsFallback() {
        let copy = LoadAdvisoryCopy.copy(completedCount: 2, advisory: nil)
        #expect(copy == "Building momentum — listen to your body.")
    }

    @Test(.tags(.loadAdvisor))
    func nilAdvisoryCompletedThreeOrMoreReturnsFallback() {
        let copy = LoadAdvisoryCopy.copy(completedCount: 3, advisory: nil)
        #expect(copy == "Solid session — the rest are optional.")
    }

    // MARK: - Taper

    @Test(.tags(.loadAdvisor))
    func taperWithNoRemainingReturnsGoodPlaceToStop() throws {
        let advisory = makeAdvisory(recommendedCount: 2, preTestTaperActive: true)
        let copy = LoadAdvisoryCopy.copy(completedCount: 2, advisory: advisory)
        #expect(copy == "Test day tomorrow — good place to stop.")
    }

    @Test(.tags(.loadAdvisor))
    func taperWithNegativeRemainingReturnsGoodPlaceToStop() throws {
        let advisory = makeAdvisory(recommendedCount: 2, preTestTaperActive: true)
        let copy = LoadAdvisoryCopy.copy(completedCount: 3, advisory: advisory)
        #expect(copy == "Test day tomorrow — good place to stop.")
    }

    @Test(.tags(.loadAdvisor))
    func taperWithOneRemainingReturnsOnMoreIsFine() throws {
        let advisory = makeAdvisory(recommendedCount: 3, preTestTaperActive: true)
        let copy = LoadAdvisoryCopy.copy(completedCount: 2, advisory: advisory)
        #expect(copy == "One more is fine — test day tomorrow.")
    }

    @Test(.tags(.loadAdvisor))
    func taperWithTwoOrMoreRemainingReturnsKeepLight() throws {
        let advisory = makeAdvisory(recommendedCount: 4, preTestTaperActive: true)
        let copy = LoadAdvisoryCopy.copy(completedCount: 2, advisory: advisory)
        #expect(copy == "Test day tomorrow — keep today light.")
    }

    // MARK: - Taper takes priority over overload and lookback

    @Test(.tags(.loadAdvisor))
    func taperTakesPriorityOverOverloadedGroups() throws {
        let advisory = makeAdvisory(
            recommendedCount: 2,
            overloadedGroups: [.lower],
            preTestTaperActive: true
        )
        let copy = LoadAdvisoryCopy.copy(completedCount: 2, advisory: advisory)
        #expect(copy == "Test day tomorrow — good place to stop.")
    }

    @Test(.tags(.loadAdvisor))
    func taperTakesPriorityOverLookback() throws {
        let advisory = makeAdvisory(
            recommendedCount: 2,
            preTestTaperActive: true,
            lookbackPenaltyActive: true
        )
        let copy = LoadAdvisoryCopy.copy(completedCount: 2, advisory: advisory)
        #expect(copy == "Test day tomorrow — good place to stop.")
    }

    // MARK: - Overloaded groups (all six MuscleGroup cases)

    @Test(.tags(.loadAdvisor), arguments: [
        (MuscleGroup.lower,          "Your lower body is carrying a lot today."),
        (MuscleGroup.lowerPosterior, "Your posterior chain is carrying a lot today."),
        (MuscleGroup.upperPush,      "Your pushing muscles are carrying a lot today."),
        (MuscleGroup.upperPull,      "Your pulling muscles are carrying a lot today."),
        (MuscleGroup.coreFlexion,    "Your core is carrying a lot today."),
        (MuscleGroup.coreStability,  "Your core is carrying a lot today."),
    ])
    func overloadedGroupCopy(group: MuscleGroup, expected: String) throws {
        let advisory = makeAdvisory(recommendedCount: 1, overloadedGroups: [group])
        let copy = LoadAdvisoryCopy.copy(completedCount: 2, advisory: advisory)
        #expect(copy == expected)
    }

    // MARK: - Overloaded takes priority over lookback

    @Test(.tags(.loadAdvisor))
    func overloadedTakesPriorityOverLookback() throws {
        let advisory = makeAdvisory(
            recommendedCount: 1,
            overloadedGroups: [.lower],
            lookbackPenaltyActive: true
        )
        let copy = LoadAdvisoryCopy.copy(completedCount: 2, advisory: advisory)
        #expect(copy == "Your lower body is carrying a lot today.")
    }

    // MARK: - Lookback

    @Test(.tags(.loadAdvisor))
    func lookbackPenaltyReturnsHeavySessionCopy() throws {
        let advisory = makeAdvisory(recommendedCount: 3, lookbackPenaltyActive: true)
        let copy = LoadAdvisoryCopy.copy(completedCount: 1, advisory: advisory)
        #expect(copy == "Heavy session yesterday — take it easy today.")
    }

    // MARK: - Count-based defaults

    @Test(.tags(.loadAdvisor))
    func countDefaultHitRecommendedLoad() throws {
        let advisory = makeAdvisory(recommendedCount: 2)
        let copy = LoadAdvisoryCopy.copy(completedCount: 2, advisory: advisory)
        #expect(copy == "You've hit today's recommended load.")
    }

    @Test(.tags(.loadAdvisor))
    func countDefaultOneMoreWithinBudget() throws {
        let advisory = makeAdvisory(recommendedCount: 3)
        let copy = LoadAdvisoryCopy.copy(completedCount: 2, advisory: advisory)
        #expect(copy == "One more is within your budget.")
    }

    @Test(.tags(.loadAdvisor))
    func countDefaultPlentyOfRoom() throws {
        let advisory = makeAdvisory(recommendedCount: 4)
        let copy = LoadAdvisoryCopy.copy(completedCount: 2, advisory: advisory)
        #expect(copy == "Plenty of room to keep going.")
    }

    // MARK: - Sort order: first rawValue-sorted group wins
    // The advisor returns overloadedGroups sorted by rawValue string (e.g. "core_flexion" < "lower").
    // LoadAdvisoryCopy relies on this contract and uses .first without re-sorting.

    @Test(.tags(.loadAdvisor))
    func firstRawValueSortedGroupWinsWhenMultipleOverloaded() throws {
        // Advisor sorts by rawValue: "core_flexion" < "lower", so coreFlexion is first
        let sortedAdvisory = makeAdvisory(
            recommendedCount: 1,
            overloadedGroups: [.coreFlexion, .lower]
        )
        let copy = LoadAdvisoryCopy.copy(completedCount: 2, advisory: sortedAdvisory)
        #expect(copy == "Your core is carrying a lot today.")
    }

    // MARK: - Helpers

    private func makeAdvisory(
        recommendedCount: Int,
        overloadedGroups: [MuscleGroup] = [],
        cautionGroups: [MuscleGroup] = [],
        preTestTaperActive: Bool = false,
        lookbackPenaltyActive: Bool = false,
        budgetFraction: Double = 0.5
    ) -> LoadAdvisory {
        LoadAdvisory(
            recommendedCount: recommendedCount,
            overloadedGroups: overloadedGroups,
            cautionGroups: cautionGroups,
            preTestTaperActive: preTestTaperActive,
            lookbackPenaltyActive: lookbackPenaltyActive,
            budgetFraction: budgetFraction
        )
    }
}
