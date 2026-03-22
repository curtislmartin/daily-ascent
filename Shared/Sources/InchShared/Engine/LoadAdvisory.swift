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
