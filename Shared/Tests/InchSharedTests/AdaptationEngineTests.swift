import Testing
import Foundation
@testable import InchShared

struct ExerciseEnrolmentAdaptationTests {

    @Test func newEnrolmentHasEmptyRollingWindows() {
        let enrolment = ExerciseEnrolment()
        #expect(enrolment.recentDifficultyRatings.isEmpty)
        #expect(enrolment.recentCompletionRatios.isEmpty)
    }

    @Test func needsRepeatDefaultsFalse() {
        let enrolment = ExerciseEnrolment()
        #expect(enrolment.needsRepeat == false)
    }

    @Test func isRepeatSessionDefaultsFalse() {
        let enrolment = ExerciseEnrolment()
        #expect(enrolment.isRepeatSession == false)
    }

    @Test func sessionPrescriptionOverrideDefaultsNil() {
        let enrolment = ExerciseEnrolment()
        #expect(enrolment.sessionPrescriptionOverride == nil)
    }
}

struct AdaptationEngineTests {

    @Test func noActionWhenBelowThreshold() {
        let enrolment = ExerciseEnrolment()
        enrolment.recentCompletionRatios = [0.90, 0.85]
        let result = AdaptationEngine().evaluate(enrolment: enrolment)
        #expect(result == .noAction)
    }

    @Test func repeatDayWhenTwoConsecutiveLowRatios() {
        let enrolment = ExerciseEnrolment()
        enrolment.recentCompletionRatios = [0.60, 0.65]
        let result = AdaptationEngine().evaluate(enrolment: enrolment)
        if case .repeatDay = result { } else {
            #expect(Bool(false), "Expected .repeatDay, got \(result)")
        }
    }

    @Test func repeatDayWhenTwoConsecutiveTooHardRatings() {
        let enrolment = ExerciseEnrolment()
        enrolment.recentDifficultyRatings = [
            DifficultyRating.tooHard.rawValue,
            DifficultyRating.tooHard.rawValue
        ]
        let result = AdaptationEngine().evaluate(enrolment: enrolment)
        if case .repeatDay = result { } else {
            #expect(Bool(false), "Expected .repeatDay, got \(result)")
        }
    }

    @Test func noRepeatWhenOnlyOneHardSession() {
        let enrolment = ExerciseEnrolment()
        enrolment.recentCompletionRatios = [0.90, 0.55]
        let result = AdaptationEngine().evaluate(enrolment: enrolment)
        #expect(result == .noAction)
    }

    @Test func earlyTestAfterThreeConsecutiveTooEasy() {
        let enrolment = ExerciseEnrolment()
        enrolment.recentDifficultyRatings = [
            DifficultyRating.tooEasy.rawValue,
            DifficultyRating.tooEasy.rawValue,
            DifficultyRating.tooEasy.rawValue
        ]
        let result = AdaptationEngine().evaluate(enrolment: enrolment)
        if case .earlyTestEligible = result { } else {
            #expect(Bool(false), "Expected .earlyTestEligible, got \(result)")
        }
    }

    @Test func noEarlyTestWithTwoTooEasy() {
        let enrolment = ExerciseEnrolment()
        enrolment.recentDifficultyRatings = [
            DifficultyRating.tooEasy.rawValue,
            DifficultyRating.tooEasy.rawValue
        ]
        let result = AdaptationEngine().evaluate(enrolment: enrolment)
        #expect(result == .noAction)
    }

    @Test func prescriptionReductionAfterFailedRepeat() {
        let enrolment = ExerciseEnrolment()
        enrolment.isRepeatSession = true
        enrolment.recentCompletionRatios = [0.90, 0.60]
        let result = AdaptationEngine().evaluate(enrolment: enrolment)
        if case .prescriptionReduction(let multiplier, _) = result {
            #expect(multiplier == 0.80)
        } else {
            #expect(Bool(false), "Expected .prescriptionReduction, got \(result)")
        }
    }

    @Test func noPrescriptionReductionIfRepeatSessionPassed() {
        let enrolment = ExerciseEnrolment()
        enrolment.isRepeatSession = true
        enrolment.recentCompletionRatios = [0.90, 0.85]
        let result = AdaptationEngine().evaluate(enrolment: enrolment)
        #expect(result == .noAction)
    }
}

struct SchedulingEngineRepeatTests {

    func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func makeLevel(
        pattern: [Int] = [2, 2, 3],
        totalDays: Int = 10,
        testTarget: Int = 20
    ) -> LevelSnapshot {
        LevelSnapshot(
            level: 1,
            restDayPattern: pattern,
            totalDays: totalDays,
            extraRestBeforeTest: nil,
            testTarget: testTarget
        )
    }

    @Test func repeatSessionFlagSetWhenNeedsRepeatTrue() throws {
        let enrolment = ExerciseEnrolment(
            currentLevel: 1,
            currentDay: 3,
            lastCompletedDate: makeDate(2026, 4, 1),
            restPatternIndex: 2
        )
        enrolment.needsRepeat = true

        let engine = SchedulingEngine()
        let level = makeLevel()
        let snapshot = EnrolmentSnapshot(enrolment)

        // Apply completion — SchedulingEngine doesn't know about needsRepeat,
        // so the writeBack hook applies the repeat logic
        let updated = engine.applyCompletion(
            to: snapshot,
            level: level,
            actualDate: makeDate(2026, 4, 1),
            totalReps: 10
        )
        engine.writeBack(updated, to: enrolment, nextDate: nil, applyRepeatIfNeeded: true)

        // currentDay should still be 3 (not advanced)
        #expect(enrolment.currentDay == 3)
        // isRepeatSession should now be true
        #expect(enrolment.isRepeatSession == true)
        // needsRepeat should be cleared
        #expect(enrolment.needsRepeat == false)
    }

    @Test func repeatSessionClearedOnCompletion() throws {
        let enrolment = ExerciseEnrolment(
            currentLevel: 1,
            currentDay: 3,
            lastCompletedDate: makeDate(2026, 4, 3),
            restPatternIndex: 2
        )
        enrolment.isRepeatSession = true
        enrolment.needsRepeat = false

        let engine = SchedulingEngine()
        let level = makeLevel()
        let snapshot = EnrolmentSnapshot(enrolment)

        let updated = engine.applyCompletion(
            to: snapshot,
            level: level,
            actualDate: makeDate(2026, 4, 3),
            totalReps: 10
        )
        engine.writeBack(updated, to: enrolment, nextDate: nil, applyRepeatIfNeeded: true)

        // After completing a repeat session, isRepeatSession is cleared
        #expect(enrolment.isRepeatSession == false)
        // Day should advance normally
        #expect(enrolment.currentDay == 4)
    }
}
