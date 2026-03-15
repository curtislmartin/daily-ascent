import Foundation
import SwiftData

@Model
final class ExerciseEnrolment {
    #Index<ExerciseEnrolment>([\.nextScheduledDate])

    var enrolledAt: Date = Date.now
    var isActive: Bool = true

    var currentLevel: Int = 1
    var currentDay: Int = 1
    var lastCompletedDate: Date? = nil
    var nextScheduledDate: Date? = nil

    var restPatternIndex: Int = 0

    var exerciseDefinition: ExerciseDefinition?

    @Relationship(deleteRule: .cascade, inverse: \CompletedSet.enrolment)
    var completedSets: [CompletedSet]? = []

    init(
        enrolledAt: Date = Date.now,
        isActive: Bool = true,
        currentLevel: Int = 1,
        currentDay: Int = 1,
        lastCompletedDate: Date? = nil,
        nextScheduledDate: Date? = nil,
        restPatternIndex: Int = 0
    ) {
        self.enrolledAt = enrolledAt
        self.isActive = isActive
        self.currentLevel = currentLevel
        self.currentDay = currentDay
        self.lastCompletedDate = lastCompletedDate
        self.nextScheduledDate = nextScheduledDate
        self.restPatternIndex = restPatternIndex
    }
}
