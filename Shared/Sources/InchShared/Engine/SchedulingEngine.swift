import Foundation
import SwiftData

public struct SchedulingEngine: Sendable {
    static let interLevelGapDays = 2

    public init() {}

    // MARK: - Date Computation

    /// Compute the next scheduled date given current enrolment and level state.
    /// Returns nil when the exercise programme is complete (all L3 passed).
    public func computeNextDate(
        enrolment: EnrolmentSnapshot,
        level: LevelSnapshot
    ) -> Date? {
        guard enrolment.isActive else { return nil }

        // First training day ever — start on enrolment date
        guard let lastCompleted = enrolment.lastCompletedDate else {
            return enrolment.enrolledAt
        }

        // Level complete — transition to next level or programme end
        if enrolment.currentDay > level.totalDays {
            if enrolment.currentLevel < 3 {
                return lastCompleted.addingDays(Self.interLevelGapDays)
            } else {
                return nil
            }
        }

        // Extra rest before test day
        let nextDayNumber = enrolment.currentDay
        let isNextDayTest = nextDayNumber == level.totalDays
        if isNextDayTest, let extra = level.extraRestBeforeTest {
            return lastCompleted.addingDays(extra)
        }

        // Normal rest pattern
        let pattern = level.restDayPattern
        let gapDays = pattern[enrolment.restPatternIndex % pattern.count]
        return lastCompleted.addingDays(gapDays)
    }

    // MARK: - Day Completion

    /// Apply the result of completing a training day.
    /// Returns an updated EnrolmentSnapshot. Caller is responsible for
    /// writing the new values back to the @Model object.
    public func applyCompletion(
        to enrolment: EnrolmentSnapshot,
        level: LevelSnapshot,
        actualDate: Date,
        totalReps: Int
    ) -> EnrolmentSnapshot {
        var updated = enrolment
        updated.lastCompletedDate = actualDate

        let isTestDay = enrolment.currentDay == level.totalDays

        if isTestDay {
            if totalReps >= level.testTarget {
                // Test passed
                if updated.currentLevel < 3 {
                    updated.currentLevel += 1
                    updated.currentDay = 1
                    updated.restPatternIndex = 0
                } else {
                    updated.isActive = false
                }
            }
            // Test failed: currentDay and currentLevel unchanged; retry applies extra rest
        } else {
            updated.currentDay += 1
            updated.restPatternIndex += 1
        }

        return updated
    }

    // MARK: - Write-back helper

    /// Apply a computed EnrolmentSnapshot back to the @Model object.
    public func writeBack(_ snapshot: EnrolmentSnapshot, to enrolment: ExerciseEnrolment, nextDate: Date?) {
        enrolment.currentLevel = snapshot.currentLevel
        enrolment.currentDay = snapshot.currentDay
        enrolment.lastCompletedDate = snapshot.lastCompletedDate
        enrolment.restPatternIndex = snapshot.restPatternIndex
        enrolment.isActive = snapshot.isActive
        enrolment.nextScheduledDate = nextDate
    }
}
