import Testing
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
