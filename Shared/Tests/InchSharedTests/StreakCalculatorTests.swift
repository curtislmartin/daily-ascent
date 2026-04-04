import Testing
import Foundation
@testable import InchShared

struct StreakCalculatorTests {
    let calc = StreakCalculator()

    func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.startOfDay(for: Calendar.current.date(from: components)!)
    }

    // MARK: - Test 10: Partial completion maintains streak

    @Test(.tags(.streak))
    func partialCompletionMaintainsStreak() {
        var state = StreakStateDTO(currentStreak: 3, longestStreak: 5,
                                   lastActiveDate: makeDate(2026, 3, 14))
        calc.update(state: &state, today: makeDate(2026, 3, 15),
                    hadDueExercises: true, completedAny: true)
        #expect(state.currentStreak == 4)
    }

    // MARK: - Test 11: Rest day never breaks streak

    @Test(.tags(.streak))
    func restDayDoesNotBreakStreak() {
        var state = StreakStateDTO(currentStreak: 3, longestStreak: 5,
                                   lastActiveDate: makeDate(2026, 3, 14))
        calc.update(state: &state, today: makeDate(2026, 3, 15),
                    hadDueExercises: false, completedAny: false)
        #expect(state.currentStreak == 3)
    }

    // MARK: - Test 12: Complete skip breaks streak

    @Test(.tags(.streak))
    func completeSkipBreaksStreak() {
        var state = StreakStateDTO(currentStreak: 3, longestStreak: 5,
                                   lastActiveDate: makeDate(2026, 3, 14))
        calc.update(state: &state, today: makeDate(2026, 3, 15),
                    hadDueExercises: true, completedAny: false)
        #expect(state.currentStreak == 0)
    }

    @Test(.tags(.streak))
    func longestStreakUpdatesWhenExceeded() {
        var state = StreakStateDTO(currentStreak: 5, longestStreak: 5,
                                   lastActiveDate: makeDate(2026, 3, 14))
        calc.update(state: &state, today: makeDate(2026, 3, 15),
                    hadDueExercises: true, completedAny: true)
        #expect(state.longestStreak == 6)
    }

    @Test(.tags(.streak))
    func firstEverCompletionStartsStreakAt1() {
        var state = StreakStateDTO(currentStreak: 0, longestStreak: 0, lastActiveDate: nil)
        calc.update(state: &state, today: makeDate(2026, 3, 15),
                    hadDueExercises: true, completedAny: true)
        #expect(state.currentStreak == 1)
        #expect(state.longestStreak == 1)
    }

    @Test(.tags(.streak))
    func gapOfMoreThanOneDayResetsStreak() {
        var state = StreakStateDTO(currentStreak: 5, longestStreak: 5,
                                   lastActiveDate: makeDate(2026, 3, 10))
        // lastActive was March 10, today is March 15 (5-day gap)
        calc.update(state: &state, today: makeDate(2026, 3, 15),
                    hadDueExercises: true, completedAny: true)
        #expect(state.currentStreak == 1, "Large gap should reset streak to 1")
    }

    // MARK: - Training after rest day

    @Test(.tags(.streak))
    func trainingAfterRestDayMaintainsStreak() {
        // lastActive March 25, rest day March 26, trains March 27
        // previousDueDate tells the calculator that March 25 was the last training day
        var state = StreakStateDTO(currentStreak: 5, longestStreak: 5,
                                   lastActiveDate: makeDate(2026, 3, 25))
        calc.update(state: &state, today: makeDate(2026, 3, 27),
                    hadDueExercises: true, completedAny: true,
                    previousDueDate: makeDate(2026, 3, 25))
        #expect(state.currentStreak == 6)
    }

    @Test(.tags(.streak))
    func longestStreakIsNotReducedOnReset() {
        var state = StreakStateDTO(currentStreak: 5, longestStreak: 10,
                                   lastActiveDate: makeDate(2026, 3, 14))
        calc.update(state: &state, today: makeDate(2026, 3, 15),
                    hadDueExercises: true, completedAny: false)
        #expect(state.longestStreak == 10, "longestStreak should not change on reset")
    }

    // MARK: - recalculateStreak

    @Test(.tags(.streak))
    func recalculate_consecutiveDays_returnsCorrectCount() {
        // Worked out March 30, 31, April 1 — streak should be 3
        let dates = [makeDate(2026, 3, 30), makeDate(2026, 3, 31), makeDate(2026, 4, 1)]
        #expect(calc.recalculateStreak(from: dates, today: makeDate(2026, 4, 1)) == 3)
    }

    @Test(.tags(.streak))
    func recalculate_withRestDayGap_countsCorrectly() {
        // Trained Monday + Wednesday (one rest day between) — streak 2
        let dates = [makeDate(2026, 3, 30), makeDate(2026, 4, 1)]
        #expect(calc.recalculateStreak(from: dates, today: makeDate(2026, 4, 1)) == 2)
    }

    @Test(.tags(.streak))
    func recalculate_withTwoRestDayGap_countsCorrectly() {
        // Max scheduled gap is 3 days — still one streak
        let dates = [makeDate(2026, 3, 29), makeDate(2026, 4, 1)]
        #expect(calc.recalculateStreak(from: dates, today: makeDate(2026, 4, 1)) == 2)
    }

    @Test(.tags(.streak))
    func recalculate_gapTooLarge_breaksStreak() {
        // Gap of 4 days — streak resets to 1
        let dates = [makeDate(2026, 3, 28), makeDate(2026, 4, 1)]
        #expect(calc.recalculateStreak(from: dates, today: makeDate(2026, 4, 1)) == 1)
    }

    @Test(.tags(.streak))
    func recalculate_noWorkoutTodayOrYesterday_returnsZero() {
        // Last workout was 3 days ago — streak is no longer active
        let dates = [makeDate(2026, 3, 29)]
        #expect(calc.recalculateStreak(from: dates, today: makeDate(2026, 4, 1)) == 0)
    }

    @Test(.tags(.streak))
    func recalculate_noHistory_returnsZero() {
        #expect(calc.recalculateStreak(from: [], today: makeDate(2026, 4, 1)) == 0)
    }

    @Test(.tags(.streak))
    func recalculate_duplicateDatesFromMultipleSets_countedOnce() {
        // Same day, multiple sets for different exercises — should count as 1 day
        let dates = [makeDate(2026, 3, 31), makeDate(2026, 3, 31),
                     makeDate(2026, 4, 1),  makeDate(2026, 4, 1)]
        #expect(calc.recalculateStreak(from: dates, today: makeDate(2026, 4, 1)) == 2)
    }

    @Test(.tags(.streak))
    func recalculate_workedOutYesterdayNotToday_stillActive() {
        let dates = [makeDate(2026, 3, 31)]
        #expect(calc.recalculateStreak(from: dates, today: makeDate(2026, 4, 1)) == 1)
    }

    // MARK: - shouldBreakStreak

    @Test(.tags(.streak))
    func shouldBreakStreak_withOverdueExercises_returnsTrue() {
        // Overdue exercises mean a scheduled session was missed — streak should break.
        #expect(calc.shouldBreakStreak(currentStreak: 2, hasOverdueExercises: true) == true)
    }

    @Test(.tags(.streak))
    func shouldBreakStreak_noOverdueExercises_returnsFalse() {
        // All exercises due today or later — nothing was missed.
        #expect(calc.shouldBreakStreak(currentStreak: 2, hasOverdueExercises: false) == false)
    }

    @Test(.tags(.streak))
    func shouldBreakStreak_noCurrentStreak_returnsFalse() {
        // No streak to break regardless of overdue state.
        #expect(calc.shouldBreakStreak(currentStreak: 0, hasOverdueExercises: true) == false)
    }

    @Test(.tags(.streak))
    func shouldBreakStreak_restDay_returnsFalse() {
        // On a rest day no exercises are overdue, so hasOverdueExercises is false.
        #expect(calc.shouldBreakStreak(currentStreak: 5, hasOverdueExercises: false) == false)
    }

    @Test(.tags(.streak))
    func shouldBreakStreak_missedDayWithoutOpeningApp_returnsTrue() {
        // The previous bug: user trained D-2, skipped D-1 without opening the app,
        // opens D. nextScheduledDate is still D-1 → overdue → streak breaks.
        #expect(calc.shouldBreakStreak(currentStreak: 5, hasOverdueExercises: true) == true)
    }
}
