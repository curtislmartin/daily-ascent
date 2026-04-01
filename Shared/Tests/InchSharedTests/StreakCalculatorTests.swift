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
    func shouldBreakStreak_missedDay_returnsTrue() {
        // Trained March 30, skipped March 31, opens app April 1
        #expect(calc.shouldBreakStreak(
            currentStreak: 2,
            lastActiveDate: makeDate(2026, 3, 30),
            lastDueDate: makeDate(2026, 3, 31),
            today: makeDate(2026, 4, 1),
            isRestDay: false
        ) == true)
    }

    @Test(.tags(.streak))
    func shouldBreakStreak_trainedOnLastDueDate_returnsFalse() {
        // Trained March 31, opens app April 1, lastDue still March 31
        #expect(calc.shouldBreakStreak(
            currentStreak: 2,
            lastActiveDate: makeDate(2026, 3, 31),
            lastDueDate: makeDate(2026, 3, 31),
            today: makeDate(2026, 4, 1),
            isRestDay: false
        ) == false)
    }

    @Test(.tags(.streak))
    func shouldBreakStreak_lastDueIsToday_returnsFalse() {
        // loadToday was already called once this session — lastDueDate has been
        // advanced to today. The second call must not falsely break the streak.
        #expect(calc.shouldBreakStreak(
            currentStreak: 2,
            lastActiveDate: makeDate(2026, 3, 31),
            lastDueDate: makeDate(2026, 4, 1),   // already advanced to today
            today: makeDate(2026, 4, 1),
            isRestDay: false
        ) == false)
    }

    @Test(.tags(.streak))
    func shouldBreakStreak_acrossMonthBoundary_doubleCallDoesNotBreak() {
        // Exact scenario that caused the April 1 bug:
        // Trained March 31, double-load on April 1 after lastDue advanced to April 1.
        #expect(calc.shouldBreakStreak(
            currentStreak: 3,
            lastActiveDate: makeDate(2026, 3, 31),
            lastDueDate: makeDate(2026, 4, 1),
            today: makeDate(2026, 4, 1),
            isRestDay: false
        ) == false)
    }

    @Test(.tags(.streak))
    func shouldBreakStreak_restDay_returnsFalse() {
        #expect(calc.shouldBreakStreak(
            currentStreak: 5,
            lastActiveDate: makeDate(2026, 3, 30),
            lastDueDate: makeDate(2026, 3, 30),
            today: makeDate(2026, 4, 1),
            isRestDay: true
        ) == false)
    }

    @Test(.tags(.streak))
    func shouldBreakStreak_noCurrentStreak_returnsFalse() {
        #expect(calc.shouldBreakStreak(
            currentStreak: 0,
            lastActiveDate: makeDate(2026, 3, 30),
            lastDueDate: makeDate(2026, 3, 31),
            today: makeDate(2026, 4, 1),
            isRestDay: false
        ) == false)
    }

    @Test(.tags(.streak))
    func shouldBreakStreak_noLastDueDate_returnsFalse() {
        // Upgrade safety: pre-existing installs may have no lastDueDate
        #expect(calc.shouldBreakStreak(
            currentStreak: 3,
            lastActiveDate: makeDate(2026, 3, 30),
            lastDueDate: nil,
            today: makeDate(2026, 4, 1),
            isRestDay: false
        ) == false)
    }
}
