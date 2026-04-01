/// Derives the one-line copy string for the Today session card based on advisory signals.
/// Priority: taper → overloaded group → lookback → count-based default → nil fallback.
public enum LoadAdvisoryCopy {

    // MARK: - Phrase pools (internal for testability)

    static let overloadPhrases: [String] = [
        "That's the most demanding work done — take the rest at your own pace.",
        "The hard part is behind you — keep the rest of today comfortable.",
        "You've put in real effort — take it steady with whatever's left.",
        "Solid, demanding work in the bank — no need to push hard today.",
        "The toughest part of today is done — listen to your body from here.",
        "Good work — your body has real strain to process. Keep the rest easy.",
        "The heavy lifting is done — take the rest at your own pace.",
        "You've earned some breathing room — keep the rest steady.",
        "Strong session — take it easy with anything else today.",
        "That's a genuinely demanding session done — no need to pile on.",
    ]

    static let taperStopPhrases: [String] = [
        "Test day tomorrow — this is a great place to stop.",
        "Save your energy — you've got a test day coming up.",
        "Good session — rest up, test day is tomorrow.",
        "You're ready for tomorrow — no need to add more today.",
        "Smart to wrap up here — test day is just around the corner.",
    ]

    static let taperOneMorePhrases: [String] = [
        "One more is fine — test day is tomorrow though.",
        "Room for one more, then save it for your test day.",
        "One more won't hurt — just keep test day in mind.",
        "You've got space for one more — test day is close.",
    ]

    static let taperLightPhrases: [String] = [
        "Test day tomorrow — keep today light.",
        "You've got a test coming up — take it easy today.",
        "Test day is close — no need to max out today.",
        "Save something for tomorrow's test — keep today moderate.",
        "Test day tomorrow — steady is the way to go.",
    ]

    static let lookbackPhrases: [String] = [
        "Heavy session yesterday — your body needs a lighter day today.",
        "You worked hard yesterday — take it easy today.",
        "Yesterday was demanding — give your body some space today.",
        "Your body is still processing yesterday — keep today comfortable.",
        "Yesterday's hard work counts — take today steady.",
        "After yesterday's session, today's a good day to go easy.",
    ]

    static let budgetDonePhrases: [String] = [
        "You've hit today's recommended load — well done.",
        "That's today's session done — great work.",
        "You've done what today called for — rest up.",
        "Recommended load reached — solid session.",
        "Today's target is met — time to recover.",
    ]

    static let budgetOneMorePhrases: [String] = [
        "One more is within your budget.",
        "Room for one more if you feel up to it.",
        "You've got space for one more today.",
        "One more won't push you over — go for it if you want.",
        "One more is on the table if you're feeling good.",
    ]

    static let budgetPlentyPhrases: [String] = [
        "Plenty of room to keep going.",
        "You're well within today's budget — keep it up.",
        "Good progress — plenty left in the tank.",
        "You're moving well — lots of budget left today.",
        "Great start — keep going at your pace.",
    ]

    static let fallbackOnePhrases: [String] = [
        "Good start — keep going if you feel up to it.",
        "First one done — build on that.",
        "Off to a good start — keep the momentum going.",
        "One down — keep it going.",
        "Great start — see how many more feel right today.",
    ]

    static let fallbackTwoPhrases: [String] = [
        "Building momentum — listen to your body.",
        "Good progress — you're in your stride now.",
        "Two in — you're building well today.",
        "Nice work so far — keep it going.",
        "Good session so far — keep going if it feels right.",
    ]

    static let fallbackManyPhrases: [String] = [
        "Solid session — anything else is a bonus.",
        "You've done real work today — anything more is a bonus.",
        "Strong session — keep going if you've got more in you.",
        "Great work today — whatever else you do is a bonus.",
        "You're putting in a great session — keep it up.",
    ]

    // MARK: - Public API

    /// Returns the advisory copy string for display below the session progress bar.
    /// - Parameters:
    ///   - completedCount: Number of fully-completed exercises today.
    ///   - advisory: The load advisor output. Nil until the first exercise is completed.
    public static func copy(completedCount: Int, advisory: LoadAdvisory?) -> String {
        guard let advisory else {
            return fallbackCopy(completedCount: completedCount)
        }

        let remaining = advisory.recommendedCount - completedCount

        // 1. Test day taper — most time-sensitive signal
        if advisory.preTestTaperActive {
            if remaining <= 0 {
                return pick(taperStopPhrases)
            } else if remaining == 1 {
                return pick(taperOneMorePhrases)
            } else {
                return pick(taperLightPhrases)
            }
        }

        // 2. Overloaded muscle group — high-demand exercise completed
        if !advisory.overloadedGroups.isEmpty {
            return pick(overloadPhrases)
        }

        // 3. Lookback penalty — yesterday was heavy
        if advisory.lookbackPenaltyActive {
            return pick(lookbackPhrases)
        }

        // 4. Count-based default — neutral headroom guidance
        if remaining <= 0 {
            return pick(budgetDonePhrases)
        } else if remaining == 1 {
            return pick(budgetOneMorePhrases)
        } else {
            return pick(budgetPlentyPhrases)
        }
    }

    // MARK: - Private

    private static func fallbackCopy(completedCount: Int) -> String {
        switch completedCount {
        case 1:  return pick(fallbackOnePhrases)
        case 2:  return pick(fallbackTwoPhrases)
        default: return pick(fallbackManyPhrases)
        }
    }

    private static func pick(_ phrases: [String]) -> String {
        phrases.randomElement() ?? phrases[0]
    }
}
