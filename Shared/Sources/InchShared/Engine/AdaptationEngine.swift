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
    /// Rule 3 > Rule 1 > Rule 2.
    public func evaluate(enrolment: ExerciseEnrolment) -> AdaptationResult {
        // Rule 3 (highest priority): prescription reduction after failed repeat
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

    private func twoConsecutiveHard(ratios: [Double]) -> Bool {
        guard ratios.count >= 2 else { return false }
        return ratios.suffix(2).allSatisfy { $0 < Self.hardCompletionThreshold }
    }

    private func twoConsecutiveTooHard(ratings: [String]) -> Bool {
        guard ratings.count >= 2 else { return false }
        return ratings.suffix(2).allSatisfy { $0 == DifficultyRating.tooHard.rawValue }
    }

    private func threeConsecutiveTooEasy(ratings: [String]) -> Bool {
        guard ratings.count >= 3 else { return false }
        return ratings.suffix(3).allSatisfy { $0 == DifficultyRating.tooEasy.rawValue }
    }
}
