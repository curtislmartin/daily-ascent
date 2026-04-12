import Foundation
import SwiftData

public struct SchedulingEngine: Sendable {
    public static let interLevelGapDays = 2

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
            if enrolment.currentLevel < level.maxLevel {
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
        guard !pattern.isEmpty else { return nil }
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
                if updated.currentLevel < level.maxLevel {
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

    // MARK: - Schedule Projection

    /// Projects the next training days forward from the given starting date.
    /// Simulates completions on each scheduled date to compute subsequent dates.
    /// Stops at the test day or when `count` days have been projected.
    public func projectSchedule(
        enrolment: EnrolmentSnapshot,
        level: LevelSnapshot,
        days: [DaySnapshot],
        startDate: Date,
        upTo count: Int = 10
    ) -> [ProjectedDay] {
        var projected: [ProjectedDay] = []
        var current = enrolment
        var currentDate = startDate

        while projected.count < count, current.currentDay <= level.totalDays {
            guard let prescription = days.first(where: { $0.dayNumber == current.currentDay }) else { break }

            projected.append(ProjectedDay(
                dayNumber: current.currentDay,
                scheduledDate: currentDate,
                sets: prescription.sets,
                isTest: prescription.isTest,
                testTarget: level.testTarget
            ))

            if prescription.isTest { break }

            current.lastCompletedDate = currentDate
            current.currentDay += 1
            current.restPatternIndex += 1

            guard let next = computeNextDate(enrolment: current, level: level) else { break }
            currentDate = next
        }

        return projected
    }

    // MARK: - Write-back helper

    /// Apply a computed EnrolmentSnapshot back to the @Model object.
    ///
    /// When `applyRepeatIfNeeded` is `true` (the default), the method checks the
    /// `needsRepeat` flag on the model object and handles adaptive repeat logic:
    /// - If `needsRepeat == true`: keeps `currentDay` at its current value (no
    ///   advancement), sets `isRepeatSession = true`, and clears `needsRepeat`.
    /// - If `isRepeatSession == true` (and `needsRepeat == false`): the repeat
    ///   session just completed normally, so `isRepeatSession` is cleared.
    public func writeBack(
        _ snapshot: EnrolmentSnapshot,
        to enrolment: ExerciseEnrolment,
        nextDate: Date?,
        applyRepeatIfNeeded: Bool = true
    ) {
        if applyRepeatIfNeeded && enrolment.needsRepeat {
            // Repeat the current day: do not advance day/level/patternIndex.
            enrolment.needsRepeat = false
            enrolment.isRepeatSession = true
            enrolment.lastCompletedDate = snapshot.lastCompletedDate
            enrolment.nextScheduledDate = nextDate
            return
        }

        enrolment.currentLevel = snapshot.currentLevel
        enrolment.currentDay = snapshot.currentDay
        enrolment.lastCompletedDate = snapshot.lastCompletedDate
        enrolment.restPatternIndex = snapshot.restPatternIndex
        enrolment.isActive = snapshot.isActive
        enrolment.nextScheduledDate = nextDate

        if applyRepeatIfNeeded && enrolment.isRepeatSession {
            enrolment.isRepeatSession = false
        }
    }
}
