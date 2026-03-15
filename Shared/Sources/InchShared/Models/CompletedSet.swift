import Foundation
import SwiftData

@Model
final class CompletedSet {
    #Index<CompletedSet>([\.completedAt])

    var completedAt: Date = Date.now
    var sessionDate: Date = Date.now
    var exerciseId: String = ""
    var level: Int = 0
    var dayNumber: Int = 0
    var setNumber: Int = 0
    var targetReps: Int = 0
    var actualReps: Int = 0
    var isTest: Bool = false
    var testPassed: Bool? = nil

    var countingMode: CountingMode = CountingMode.postSetConfirmation
    var setDurationSeconds: Double? = nil

    var enrolment: ExerciseEnrolment?

    @Relationship(deleteRule: .cascade, inverse: \SensorRecording.completedSet)
    var sensorRecordings: [SensorRecording]? = []

    init(
        completedAt: Date = Date.now,
        sessionDate: Date = Date.now,
        exerciseId: String = "",
        level: Int = 0,
        dayNumber: Int = 0,
        setNumber: Int = 0,
        targetReps: Int = 0,
        actualReps: Int = 0,
        isTest: Bool = false,
        testPassed: Bool? = nil,
        countingMode: CountingMode = .postSetConfirmation,
        setDurationSeconds: Double? = nil
    ) {
        self.completedAt = completedAt
        self.sessionDate = sessionDate
        self.exerciseId = exerciseId
        self.level = level
        self.dayNumber = dayNumber
        self.setNumber = setNumber
        self.targetReps = targetReps
        self.actualReps = actualReps
        self.isTest = isTest
        self.testPassed = testPassed
        self.countingMode = countingMode
        self.setDurationSeconds = setDurationSeconds
    }
}
