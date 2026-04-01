import Testing
import Foundation
@testable import InchShared

struct LoadAdvisoryCopyTests {

    // MARK: - Nil fallback

    @Test(.tags(.loadAdvisor))
    func nilAdvisoryCompletedOneReturnsFallbackOnePhrase() {
        let copy = LoadAdvisoryCopy.copy(completedCount: 1, advisory: nil)
        #expect(LoadAdvisoryCopy.fallbackOnePhrases.contains(copy))
    }

    @Test(.tags(.loadAdvisor))
    func nilAdvisoryCompletedTwoReturnsFallbackTwoPhrase() {
        let copy = LoadAdvisoryCopy.copy(completedCount: 2, advisory: nil)
        #expect(LoadAdvisoryCopy.fallbackTwoPhrases.contains(copy))
    }

    @Test(.tags(.loadAdvisor))
    func nilAdvisoryCompletedThreeOrMoreReturnsFallbackManyPhrase() {
        let copy = LoadAdvisoryCopy.copy(completedCount: 3, advisory: nil)
        #expect(LoadAdvisoryCopy.fallbackManyPhrases.contains(copy))
    }

    // MARK: - Taper

    @Test(.tags(.loadAdvisor))
    func taperWithNoRemainingReturnsStopPhrase() {
        let advisory = makeAdvisory(recommendedCount: 2, preTestTaperActive: true)
        let copy = LoadAdvisoryCopy.copy(completedCount: 2, advisory: advisory)
        #expect(LoadAdvisoryCopy.taperStopPhrases.contains(copy))
    }

    @Test(.tags(.loadAdvisor))
    func taperWithNegativeRemainingReturnsStopPhrase() {
        let advisory = makeAdvisory(recommendedCount: 2, preTestTaperActive: true)
        let copy = LoadAdvisoryCopy.copy(completedCount: 3, advisory: advisory)
        #expect(LoadAdvisoryCopy.taperStopPhrases.contains(copy))
    }

    @Test(.tags(.loadAdvisor))
    func taperWithOneRemainingReturnsOneMorePhrase() {
        let advisory = makeAdvisory(recommendedCount: 3, preTestTaperActive: true)
        let copy = LoadAdvisoryCopy.copy(completedCount: 2, advisory: advisory)
        #expect(LoadAdvisoryCopy.taperOneMorePhrases.contains(copy))
    }

    @Test(.tags(.loadAdvisor))
    func taperWithTwoOrMoreRemainingReturnsLightPhrase() {
        let advisory = makeAdvisory(recommendedCount: 4, preTestTaperActive: true)
        let copy = LoadAdvisoryCopy.copy(completedCount: 2, advisory: advisory)
        #expect(LoadAdvisoryCopy.taperLightPhrases.contains(copy))
    }

    // MARK: - Taper takes priority over overload and lookback

    @Test(.tags(.loadAdvisor))
    func taperTakesPriorityOverOverloadedGroups() {
        let advisory = makeAdvisory(
            recommendedCount: 2,
            overloadedGroups: [.lower],
            preTestTaperActive: true
        )
        let copy = LoadAdvisoryCopy.copy(completedCount: 2, advisory: advisory)
        #expect(LoadAdvisoryCopy.taperStopPhrases.contains(copy))
    }

    @Test(.tags(.loadAdvisor))
    func taperTakesPriorityOverLookback() {
        let advisory = makeAdvisory(
            recommendedCount: 2,
            preTestTaperActive: true,
            lookbackPenaltyActive: true
        )
        let copy = LoadAdvisoryCopy.copy(completedCount: 2, advisory: advisory)
        #expect(LoadAdvisoryCopy.taperStopPhrases.contains(copy))
    }

    // MARK: - Overloaded groups

    @Test(.tags(.loadAdvisor), arguments: [
        MuscleGroup.lower,
        MuscleGroup.lowerPosterior,
        MuscleGroup.upperPush,
        MuscleGroup.upperPull,
        MuscleGroup.coreFlexion,
        MuscleGroup.coreStability,
    ])
    func overloadedGroupReturnsOverloadPhrase(group: MuscleGroup) {
        let advisory = makeAdvisory(recommendedCount: 1, overloadedGroups: [group])
        let copy = LoadAdvisoryCopy.copy(completedCount: 2, advisory: advisory)
        #expect(LoadAdvisoryCopy.overloadPhrases.contains(copy))
    }

    @Test(.tags(.loadAdvisor))
    func multipleOverloadedGroupsReturnsOverloadPhrase() {
        let advisory = makeAdvisory(
            recommendedCount: 1,
            overloadedGroups: [.coreFlexion, .lower]
        )
        let copy = LoadAdvisoryCopy.copy(completedCount: 2, advisory: advisory)
        #expect(LoadAdvisoryCopy.overloadPhrases.contains(copy))
    }

    // MARK: - Overloaded takes priority over lookback

    @Test(.tags(.loadAdvisor))
    func overloadedTakesPriorityOverLookback() {
        let advisory = makeAdvisory(
            recommendedCount: 1,
            overloadedGroups: [.lower],
            lookbackPenaltyActive: true
        )
        let copy = LoadAdvisoryCopy.copy(completedCount: 2, advisory: advisory)
        #expect(LoadAdvisoryCopy.overloadPhrases.contains(copy))
    }

    // MARK: - Lookback

    @Test(.tags(.loadAdvisor))
    func lookbackPenaltyReturnsLookbackPhrase() {
        let advisory = makeAdvisory(recommendedCount: 3, lookbackPenaltyActive: true)
        let copy = LoadAdvisoryCopy.copy(completedCount: 1, advisory: advisory)
        #expect(LoadAdvisoryCopy.lookbackPhrases.contains(copy))
    }

    // MARK: - Count-based defaults

    @Test(.tags(.loadAdvisor))
    func countDefaultHitRecommendedLoadReturnsDonePhrase() {
        let advisory = makeAdvisory(recommendedCount: 2)
        let copy = LoadAdvisoryCopy.copy(completedCount: 2, advisory: advisory)
        #expect(LoadAdvisoryCopy.budgetDonePhrases.contains(copy))
    }

    @Test(.tags(.loadAdvisor))
    func countDefaultOneMoreReturnsOneMorePhrase() {
        let advisory = makeAdvisory(recommendedCount: 3)
        let copy = LoadAdvisoryCopy.copy(completedCount: 2, advisory: advisory)
        #expect(LoadAdvisoryCopy.budgetOneMorePhrases.contains(copy))
    }

    @Test(.tags(.loadAdvisor))
    func countDefaultPlentyReturnsPlentyPhrase() {
        let advisory = makeAdvisory(recommendedCount: 4)
        let copy = LoadAdvisoryCopy.copy(completedCount: 2, advisory: advisory)
        #expect(LoadAdvisoryCopy.budgetPlentyPhrases.contains(copy))
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
