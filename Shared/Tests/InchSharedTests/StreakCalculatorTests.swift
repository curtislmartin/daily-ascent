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
}
