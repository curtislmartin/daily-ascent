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
               previousDueDate: streakState.lastDueDate)
        streakState.currentStreak = dto.currentStreak
        streakState.longestStreak = dto.longestStreak
        streakState.lastActiveDate = dto.lastActiveDate
        if hadDueExercises {
            streakState.lastDueDate = today
        }
    }
}
