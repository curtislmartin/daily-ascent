import Foundation
import SwiftData

/// Value-type DTO for streak state, used in pure-function tests.
public struct StreakStateDTO: Sendable, Equatable {
    public var currentStreak: Int
    public var longestStreak: Int
    public var lastActiveDate: Date?

    public init(currentStreak: Int = 0, longestStreak: Int = 0, lastActiveDate: Date? = nil) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastActiveDate = lastActiveDate
    }
}

public struct StreakCalculator: Sendable {
    public init() {}

    /// Pure function. Mutates `state` based on today's training activity.
    /// - Parameters:
    ///   - hadDueExercises: Whether any exercises were scheduled for today.
    ///   - completedAny: Whether the user completed at least one exercise today.
    ///   - previousDueDate: The last date before today when exercises were due. When provided,
    ///     streak continues if `lastActiveDate` matches this date — correctly treating scheduled
    ///     rest days between training sessions as transparent. When nil, falls back to checking
    ///     whether `lastActiveDate` was yesterday.
    public func update(
        state: inout StreakStateDTO,
        today: Date,
        hadDueExercises: Bool,
        completedAny: Bool,
        previousDueDate: Date? = nil
    ) {
        // Rest day — streak neither broken nor extended
        guard hadDueExercises else { return }

        if completedAny {
            let isConsecutive: Bool
            if let last = state.lastActiveDate {
                if let prev = previousDueDate {
                    isConsecutive = Calendar.current.isDate(last, inSameDayAs: prev)
                } else {
                    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today
                    isConsecutive = Calendar.current.isDate(last, inSameDayAs: yesterday)
                }
            } else {
                isConsecutive = false
            }
            state.currentStreak = isConsecutive ? state.currentStreak + 1 : 1
            state.lastActiveDate = today
            state.longestStreak = max(state.longestStreak, state.currentStreak)
        } else {
            state.currentStreak = 0
        }
    }

    /// Pure function. Derives the current streak purely from workout completion history.
    ///
    /// Walks unique training days backwards from today, counting consecutive days where
    /// the gap between adjacent sessions is ≤ 3 calendar days (matching the maximum
    /// scheduled rest gap). Stops at the first gap larger than that.
    ///
    /// This is used to self-heal the streak when the persisted value is lower than what
    /// history shows — e.g. after a false reset caused by a double `loadToday` call.
    public func recalculateStreak(from completionDates: [Date], today: Date) -> Int {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: today)

        let trainingDays = Array(
            Set(completionDates.map { cal.startOfDay(for: $0) })
        ).sorted(by: >)

        guard let mostRecent = trainingDays.first else { return 0 }

        // Streak is only active if the user trained today or yesterday
        let yesterday = cal.date(byAdding: .day, value: -1, to: todayStart)!
        guard mostRecent >= yesterday else { return 0 }

        var streak = 1
        for i in 1..<trainingDays.count {
            let gap = cal.dateComponents([.day], from: trainingDays[i], to: trainingDays[i - 1]).day ?? 0
            if gap <= 3 {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    /// Pure function. Returns true if a streak should be broken because the user missed a
    /// scheduled training day.
    ///
    /// - Parameters:
    ///   - currentStreak: The user's current streak value.
    ///   - hasOverdueExercises: Whether any active enrolment has a `nextScheduledDate` strictly
    ///     before today. This is the authoritative signal for a missed session — `nextScheduledDate`
    ///     only advances when the user completes a workout, so a past date means the session was
    ///     skipped regardless of whether the app was opened that day.
    public func shouldBreakStreak(
        currentStreak: Int,
        hasOverdueExercises: Bool
    ) -> Bool {
        guard currentStreak > 0 else { return false }
        return hasOverdueExercises
    }

    /// SwiftData variant — reads and writes the persisted StreakState model.
    public func updateStreakState(
        _ streakState: StreakState,
        today: Date,
        hadDueExercises: Bool,
        completedAny: Bool
    ) {
        var dto = StreakStateDTO(
            currentStreak: streakState.currentStreak,
            longestStreak: streakState.longestStreak,
            lastActiveDate: streakState.lastActiveDate
        )
        update(state: &dto, today: today, hadDueExercises: hadDueExercises, completedAny: completedAny,
               previousDueDate: streakState.previousLastDueDate)
        streakState.currentStreak = dto.currentStreak
        streakState.longestStreak = dto.longestStreak
        streakState.lastActiveDate = dto.lastActiveDate
        if hadDueExercises {
            streakState.lastDueDate = today
        }
    }
}
