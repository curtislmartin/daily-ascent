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
        "squats":           3,
        "pull_ups":         3,
        "rows":             3,
        "push_ups":         2,
        "dips":             2,
        "hip_hinge":        2,
        "dead_bugs":        1,
        "spinal_extension": 1,
        "plank":            1
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

        // Compute per-exercise costs, tracking per-group totals for overloadedGroups.
        // completedMuscleGroups is built from the full list upfront so both exercises
        // in a compounding pair receive the ×1.5 multiplier. This is intentional —
        // it makes the result order-independent when the pair has different base costs
        // (squats=3, hip_hinge=2). Using an incremental set would produce different
        // totals depending on which exercise was processed first.
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
