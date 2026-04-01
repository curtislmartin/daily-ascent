import Foundation
import SwiftData

@Model
public final class ExerciseEnrolment {
    public var enrolledAt: Date = Date.now
    public var isActive: Bool = true

    public var currentLevel: Int = 1
    public var currentDay: Int = 1
    public var lastCompletedDate: Date? = nil
    public var nextScheduledDate: Date? = nil

    public var restPatternIndex: Int = 0

    // MARK: - Adaptive difficulty
    public var recentDifficultyRatings: [String] = []
    public var recentCompletionRatios: [Double] = []
    public var needsRepeat: Bool = false
    public var isRepeatSession: Bool = false
    public var sessionPrescriptionOverride: Double? = nil

    public var exerciseDefinition: ExerciseDefinition?

    @Relationship(deleteRule: .cascade, inverse: \CompletedSet.enrolment)
    public var completedSets: [CompletedSet]? = []

    public init(
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
