/// Derives the one-line copy string for the Today session card based on advisory signals.
/// Priority: taper → overloaded group → lookback → count-based default → nil fallback.
public enum LoadAdvisoryCopy {

    /// Returns the advisory copy string for display below the session progress bar.
    /// - Parameters:
    ///   - completedCount: Number of fully-completed exercises today (from the banner's own param).
    ///   - advisory: The load advisor output. Nil until the first exercise is completed.
    public static func copy(completedCount: Int, advisory: LoadAdvisory?) -> String {
        guard let advisory else {
            return fallbackCopy(completedCount: completedCount)
        }

        let remaining = advisory.recommendedCount - completedCount

        // 1. Test day taper — most time-sensitive signal
        if advisory.preTestTaperActive {
            if remaining <= 0 {
                return "Test day tomorrow — good place to stop."
            } else if remaining == 1 {
                return "One more is fine — test day tomorrow."
            } else {
                return "Test day tomorrow — keep today light."
            }
        }

        // 2. Overloaded muscle group — specific recovery call-out
        // Relies on overloadedGroups being pre-sorted by rawValue (guaranteed by DailyLoadAdvisor).
        // The first group wins when multiple are overloaded.
        if let group = advisory.overloadedGroups.first {
            return overloadCopy(for: group)
        }

        // 3. Lookback penalty — yesterday was heavy
        if advisory.lookbackPenaltyActive {
            return "Heavy session yesterday — take it easy today."
        }

        // 4. Count-based default — neutral headroom guidance
        if remaining <= 0 {
            return "You've hit today's recommended load."
        } else if remaining == 1 {
            return "One more is within your budget."
        } else {
            return "Plenty of room to keep going."
        }
    }

    // MARK: - Private

    private static func fallbackCopy(completedCount: Int) -> String {
        switch completedCount {
        case 1:  return "Good start — keep going if you feel up to it."
        case 2:  return "Building momentum — listen to your body."
        default: return "Solid session — the rest are optional."
        }
    }

    private static func overloadCopy(for group: MuscleGroup) -> String {
        switch group {
        case .lower:          return "Your lower body is carrying a lot today."
        case .lowerPosterior: return "Your posterior chain is carrying a lot today."
        case .upperPush:      return "Your pushing muscles are carrying a lot today."
        case .upperPull:      return "Your pulling muscles are carrying a lot today."
        case .coreFlexion:    return "Your core is carrying a lot today."
        case .coreStability:  return "Your core is carrying a lot today." // same copy — both are core groups
        }
    }
}
