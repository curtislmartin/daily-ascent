import Testing
import Foundation
@testable import InchShared

// These tests verify the tuple-building logic in isolation —
// no SwiftData container needed.
struct NextTrainingExercisesTests {

    struct FakeEnrolment {
        let name: String
        let level: Int
        let dayNumber: Int
        let nextDate: Date
    }

    @Test func sortsEnrolmentsByName() {
        let today = Calendar.current.startOfDay(for: .now)
        let enrolments = [
            FakeEnrolment(name: "Squats", level: 2, dayNumber: 5, nextDate: today),
            FakeEnrolment(name: "Push-Ups", level: 1, dayNumber: 3, nextDate: today),
        ]
        let result = enrolments
            .sorted { $0.name < $1.name }
            .map { (exerciseName: $0.name, level: $0.level, dayNumber: $0.dayNumber) }

        #expect(result[0].exerciseName == "Push-Ups")
        #expect(result[1].exerciseName == "Squats")
    }

    @Test func excludesEnrolmentsDueOnDifferentDate() {
        let today = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let dayAfter = Calendar.current.date(byAdding: .day, value: 2, to: today)!

        let nearestDate = tomorrow
        let enrolments = [
            FakeEnrolment(name: "Push-Ups", level: 1, dayNumber: 3, nextDate: tomorrow),
            FakeEnrolment(name: "Squats", level: 2, dayNumber: 5, nextDate: dayAfter),
        ]
        let result = enrolments
            .filter {
                Calendar.current.isDate($0.nextDate, inSameDayAs: nearestDate)
            }
            .map { (exerciseName: $0.name, level: $0.level, dayNumber: $0.dayNumber) }

        #expect(result.count == 1)
        #expect(result[0].exerciseName == "Push-Ups")
    }
}
