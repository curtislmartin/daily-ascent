import Testing
import Foundation
@testable import InchShared

struct ConflictDetectorTests {
    let detector = ConflictDetector()

    func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)!
    }

    // MARK: - Test 7: Double test detection

    @Test(.tags(.conflict))
    func detectsDoubleTestOnSameDay() {
        let date = makeDate(2026, 4, 5)
        let sessions: [ProjectedSession] = [
            ProjectedSession(exerciseId: "push_ups", muscleGroup: .upperPush,
                             isTest: true, date: date, enrolmentId: "e1"),
            ProjectedSession(exerciseId: "pull_ups", muscleGroup: .upperPull,
                             isTest: true, date: date, enrolmentId: "e2"),
        ]
        let conflicts = detector.detectConflicts(in: sessions)
        let hasDoubleTest = conflicts.contains {
            if case .doubleTest = $0 { true } else { false }
        }
        #expect(hasDoubleTest)
    }

    // MARK: - Test 8: Test with same-group training

    @Test(.tags(.conflict))
    func detectsTestWithSameGroupTraining() {
        let date = makeDate(2026, 4, 10)
        let sessions: [ProjectedSession] = [
            ProjectedSession(exerciseId: "squats", muscleGroup: .lower,
                             isTest: true, date: date, enrolmentId: "e1"),
            ProjectedSession(exerciseId: "glute_bridges", muscleGroup: .lowerPosterior,
                             isTest: false, date: date, enrolmentId: "e2"),
        ]
        let conflicts = detector.detectConflicts(in: sessions)
        let hasSameGroupConflict = conflicts.contains {
            if case .testWithSameGroupTraining = $0 { true } else { false }
        }
        #expect(hasSameGroupConflict)
    }

    @Test(.tags(.conflict))
    func noConflictForUnrelatedMuscleGroups() {
        let date = makeDate(2026, 4, 5)
        let sessions: [ProjectedSession] = [
            ProjectedSession(exerciseId: "push_ups", muscleGroup: .upperPush,
                             isTest: true, date: date, enrolmentId: "e1"),
            ProjectedSession(exerciseId: "squats", muscleGroup: .lower,
                             isTest: false, date: date, enrolmentId: "e2"),
        ]
        let conflicts = detector.detectConflicts(in: sessions)
        #expect(conflicts.isEmpty)
    }

    @Test(.tags(.conflict))
    func coreGroupsConflictWithEachOther() {
        let date = makeDate(2026, 4, 5)
        let sessions: [ProjectedSession] = [
            ProjectedSession(exerciseId: "sit_ups", muscleGroup: .coreFlexion,
                             isTest: true, date: date, enrolmentId: "e1"),
            ProjectedSession(exerciseId: "dead_bugs", muscleGroup: .coreStability,
                             isTest: false, date: date, enrolmentId: "e2"),
        ]
        let conflicts = detector.detectConflicts(in: sessions)
        let hasSameGroupConflict = conflicts.contains {
            if case .testWithSameGroupTraining = $0 { true } else { false }
        }
        #expect(hasSameGroupConflict)
    }

    @Test(.tags(.conflict))
    func noConflictWhenNoSessionsOnSameDay() {
        let sessions: [ProjectedSession] = [
            ProjectedSession(exerciseId: "push_ups", muscleGroup: .upperPush,
                             isTest: true, date: makeDate(2026, 4, 5), enrolmentId: "e1"),
            ProjectedSession(exerciseId: "squats", muscleGroup: .lower,
                             isTest: true, date: makeDate(2026, 4, 6), enrolmentId: "e2"),
        ]
        let conflicts = detector.detectConflicts(in: sessions)
        #expect(conflicts.isEmpty)
    }
}
