import Foundation
import SwiftData

@Model
public final class CompletedSet {
    public var completedAt: Date = Date.now
    public var sessionDate: Date = Date.now
    public var exerciseId: String = ""
    public var level: Int = 0
    public var dayNumber: Int = 0
    public var setNumber: Int = 0
    public var targetReps: Int = 0
    public var actualReps: Int = 0
    public var isTest: Bool = false
    public var testPassed: Bool? = nil

    public var countingMode: CountingMode = CountingMode.postSetConfirmation
    public var setDurationSeconds: Double? = nil

    public var enrolment: ExerciseEnrolment?

    @Relationship(deleteRule: .cascade, inverse: \SensorRecording.completedSet)
    public var sensorRecordings: [SensorRecording]? = []

    public init(
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
