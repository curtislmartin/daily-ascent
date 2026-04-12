import Testing
import Foundation
@testable import InchShared

struct SchedulingEngineTests {
    let engine = SchedulingEngine()

    // MARK: - Helpers

    func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)!
    }

    func makeEnrolment(
        level: Int = 1,
        currentDay: Int = 1,
        lastCompleted: Date? = nil,
        patternIndex: Int = 0,
        enrolledAt: Date = Date.now
    ) -> EnrolmentSnapshot {
        EnrolmentSnapshot(
            currentLevel: level,
            currentDay: currentDay,
            lastCompletedDate: lastCompleted,
            restPatternIndex: patternIndex,
            enrolledAt: enrolledAt
        )
    }

    func makeLevel(
        level: Int = 1,
        pattern: [Int] = [2, 2, 3],
        totalDays: Int = 10,
        extraRest: Int? = nil,
        testTarget: Int = 20,
        maxLevel: Int = 3
    ) -> LevelSnapshot {
        LevelSnapshot(
            level: level,
            restDayPattern: pattern,
            totalDays: totalDays,
            extraRestBeforeTest: extraRest,
            testTarget: testTarget,
            maxLevel: maxLevel
        )
    }

    // MARK: - Test 1: Basic date calculation

    @Test(.tags(.scheduling))
    func basicDateCalculationAfterDay1() throws {
        // Push-Ups L1: pattern [2,2,3]. Complete Day 1 on March 15.
        // restPatternIndex advances to 1 after completion, currentDay becomes 2.
        let level = makeLevel(pattern: [2, 2, 3], totalDays: 10)
        let enrolment = makeEnrolment(currentDay: 2, lastCompleted: makeDate(2026, 3, 15), patternIndex: 1)
        let next = try #require(engine.computeNextDate(enrolment: enrolment, level: level))
        #expect(next == makeDate(2026, 3, 17), "Gap should be pattern[1]=2 days")
    }

    // MARK: - Test 2: Pattern cycling

    @Test(.tags(.scheduling), arguments: [
        (currentDay: 2, patternIndex: 1, lastDay: 15, expectedDay: 17),
        (currentDay: 3, patternIndex: 2, lastDay: 17, expectedDay: 20),
        (currentDay: 4, patternIndex: 0, lastDay: 20, expectedDay: 22), // pattern cycles
    ])
    func patternCycling(currentDay: Int, patternIndex: Int, lastDay: Int, expectedDay: Int) throws {
        let level = makeLevel(pattern: [2, 2, 3], totalDays: 10)
        let enrolment = makeEnrolment(
            currentDay: currentDay,
            lastCompleted: makeDate(2026, 3, lastDay),
            patternIndex: patternIndex
        )
        let next = try #require(engine.computeNextDate(enrolment: enrolment, level: level))
        #expect(next == makeDate(2026, 3, expectedDay))
    }

    // MARK: - Test 3: Extra rest before test

    @Test(.tags(.scheduling))
    func extraRestBeforeTest() throws {
        // Push-Ups L2: extraRestBeforeTest = 4, totalDays = 19, test is day 19
        let level = makeLevel(pattern: [2, 2, 3], totalDays: 19, extraRest: 4, testTarget: 50)
        // currentDay = 19 (the test day is next), lastCompleted = day 18
        let enrolment = makeEnrolment(currentDay: 19, lastCompleted: makeDate(2026, 3, 15))
        let next = try #require(engine.computeNextDate(enrolment: enrolment, level: level))
        #expect(next == makeDate(2026, 3, 19), "Extra rest of 4 days applies before test")
    }

    // MARK: - Test 4: Level transition

    @Test(.tags(.scheduling))
    func levelTransitionAdds2DayGap() throws {
        // After passing the test on March 15, currentDay advanced past totalDays (10)
        let level = makeLevel(pattern: [2, 2, 3], totalDays: 10)
        let enrolment = makeEnrolment(level: 1, currentDay: 11, lastCompleted: makeDate(2026, 3, 15))
        let next = try #require(engine.computeNextDate(enrolment: enrolment, level: level))
        #expect(next == makeDate(2026, 3, 17), "Level transition adds 2-day inter-level gap")
    }

    // MARK: - Test 5: Failed test retry uses extra rest

    @Test(.tags(.scheduling))
    func failedTestRetryUsesExtraRest() throws {
        let level = makeLevel(pattern: [2, 2, 3], totalDays: 19, extraRest: 4, testTarget: 50)
        // currentDay still at 19 (failed — not advanced), lastCompleted = today
        let enrolment = makeEnrolment(currentDay: 19, lastCompleted: makeDate(2026, 3, 15))
        let next = try #require(engine.computeNextDate(enrolment: enrolment, level: level))
        #expect(next == makeDate(2026, 3, 19), "Extra rest applies for test retries too")
    }

    // MARK: - Test: First training day uses enrolledAt

    @Test(.tags(.scheduling))
    func firstTrainingDayUsesEnrolledAt() throws {
        let level = makeLevel()
        let enrolled = makeDate(2026, 3, 15)
        let enrolment = makeEnrolment(lastCompleted: nil, enrolledAt: enrolled)
        let next = try #require(engine.computeNextDate(enrolment: enrolment, level: level))
        #expect(next == enrolled)
    }

    // MARK: - Programme completion returns nil

    @Test(.tags(.scheduling))
    func programmeCompleteReturnsNil() {
        let level = makeLevel(totalDays: 10)
        // currentLevel = 3, currentDay > totalDays = programme complete
        let enrolment = makeEnrolment(level: 3, currentDay: 11, lastCompleted: makeDate(2026, 3, 15))
        let next = engine.computeNextDate(enrolment: enrolment, level: level)
        #expect(next == nil)
    }

    // MARK: - applyCompletion: regular day

    @Test(.tags(.scheduling))
    func applyCompletionAdvancesDay() {
        let level = makeLevel(totalDays: 10)
        let enrolment = makeEnrolment(currentDay: 1, patternIndex: 0)
        let updated = engine.applyCompletion(
            to: enrolment,
            level: level,
            actualDate: makeDate(2026, 3, 15),
            totalReps: 10
        )
        #expect(updated.currentDay == 2)
        #expect(updated.restPatternIndex == 1)
        #expect(updated.lastCompletedDate == makeDate(2026, 3, 15))
    }

    // MARK: - applyCompletion: passing test

    @Test(.tags(.scheduling))
    func applyCompletionPassingTestAdvancesLevel() {
        let level = makeLevel(totalDays: 10, testTarget: 20)
        let enrolment = makeEnrolment(level: 1, currentDay: 10, patternIndex: 0)
        let updated = engine.applyCompletion(
            to: enrolment,
            level: level,
            actualDate: makeDate(2026, 3, 15),
            totalReps: 25
        )
        #expect(updated.currentLevel == 2)
        #expect(updated.currentDay == 1)
        #expect(updated.restPatternIndex == 0)
    }

    // MARK: - applyCompletion: failing test

    @Test(.tags(.scheduling))
    func applyCompletionFailedTestKeepsCurrentDay() {
        let level = makeLevel(totalDays: 10, testTarget: 20)
        let enrolment = makeEnrolment(level: 1, currentDay: 10, patternIndex: 0)
        let updated = engine.applyCompletion(
            to: enrolment,
            level: level,
            actualDate: makeDate(2026, 3, 15),
            totalReps: 15
        )
        #expect(updated.currentLevel == 1)
        #expect(updated.currentDay == 10)  // unchanged
    }

    // MARK: - maxLevel tests

    @Test(.tags(.scheduling))
    func testPassedOnMaxLevelDeactivatesEnrolment() {
        let enrolment = makeEnrolment(level: 3, currentDay: 10, lastCompleted: makeDate(2026, 3, 15))
        let level = makeLevel(level: 3, totalDays: 10, testTarget: 20, maxLevel: 3)
        let result = engine.applyCompletion(to: enrolment, level: level, actualDate: makeDate(2026, 3, 15), totalReps: 25)
        #expect(result.isActive == false)
    }

    @Test(.tags(.scheduling))
    func testPassedBelowMaxLevelAdvancesToNextLevel() {
        let enrolment = makeEnrolment(level: 0, currentDay: 8, lastCompleted: makeDate(2026, 3, 15))
        let level = makeLevel(level: 0, totalDays: 8, testTarget: 5, maxLevel: 3)
        let result = engine.applyCompletion(to: enrolment, level: level, actualDate: makeDate(2026, 3, 15), totalReps: 5)
        #expect(result.currentLevel == 1)
        #expect(result.currentDay == 1)
        #expect(result.isActive == true)
    }

    @Test(.tags(.scheduling))
    func testLevelCompleteTransitionWorksForLevel0() {
        let enrolment = makeEnrolment(level: 0, currentDay: 9, lastCompleted: makeDate(2026, 3, 15))
        let level = makeLevel(level: 0, totalDays: 8, testTarget: 5, maxLevel: 3)
        let nextDate = engine.computeNextDate(enrolment: enrolment, level: level)
        #expect(nextDate == makeDate(2026, 3, 17))
    }

    // MARK: - Test 6: Missed day then completion — schedule shifts naturally

    @Test(.tags(.scheduling))
    func missedDayCompletionShiftsSchedule() throws {
        // User was due March 20, didn't train, completed March 23 instead.
        let level = makeLevel(pattern: [2, 2, 3], totalDays: 10)
        let enrolment = makeEnrolment(currentDay: 4, lastCompleted: nil, enrolledAt: makeDate(2026, 3, 20))
        // Simulate they actually complete on March 23
        let updated = engine.applyCompletion(
            to: enrolment,
            level: level,
            actualDate: makeDate(2026, 3, 23),
            totalReps: 10
        )
        // Next date computed from March 23, not March 20
        let nextDate = try #require(engine.computeNextDate(enrolment: updated, level: level))
        // patternIndex is now 1, gap = pattern[1] = 2, so next = March 25
        #expect(nextDate == makeDate(2026, 3, 25))
    }
}
