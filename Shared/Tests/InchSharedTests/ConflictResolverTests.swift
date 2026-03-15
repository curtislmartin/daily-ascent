import Testing
import Foundation
@testable import InchShared

struct ConflictResolverTests {
    func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)!
    }

    // MARK: - Test 9: Priority ordering for double test

    @Test(.tags(.conflict))
    func resolvesDoubleTestByPushingLowerPriorityExercise() {
        let date = makeDate(2026, 4, 5)
        let sessions: [ProjectedSession] = [
            ProjectedSession(exerciseId: "push_ups", muscleGroup: .upperPush,
                             isTest: true, date: date, enrolmentId: "e1"),
            ProjectedSession(exerciseId: "pull_ups", muscleGroup: .upperPull,
                             isTest: true, date: date, enrolmentId: "e2"),
        ]
        let resolver = ConflictResolver()
        // e1 has 5 remaining days (closer to end = higher priority), e2 has 20
        let adjustments = resolver.resolve(
            conflicts: [.doubleTest(date: date, exerciseIds: ["push_ups", "pull_ups"])],
            sessions: sessions,
            remainingDays: { id in id == "e1" ? 5 : 20 }
        )
        #expect(adjustments.count == 1)
        #expect(adjustments.first?.enrolmentId == "e2", "e2 should be pushed (lower priority)")
    }

    @Test(.tags(.conflict))
    func resolvesTestWithSameGroupByPushingRegularSession() {
        let date = makeDate(2026, 4, 10)
        let sessions: [ProjectedSession] = [
            ProjectedSession(exerciseId: "squats", muscleGroup: .lower,
                             isTest: true, date: date, enrolmentId: "e1"),
            ProjectedSession(exerciseId: "glute_bridges", muscleGroup: .lowerPosterior,
                             isTest: false, date: date, enrolmentId: "e2"),
        ]
        let resolver = ConflictResolver()
        let adjustments = resolver.resolve(
            conflicts: [.testWithSameGroupTraining(date: date,
                testExerciseId: "squats", trainingExerciseId: "glute_bridges")],
            sessions: sessions,
            remainingDays: { _ in 10 }
        )
        #expect(adjustments.count == 1)
        #expect(adjustments.first?.enrolmentId == "e2", "Training session should yield to test")
    }

    @Test(.tags(.conflict))
    func maxIterationsIsSet() {
        let resolver = ConflictResolver()
        #expect(resolver.maxIterations == 5)
    }
}
