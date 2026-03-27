import Foundation
import SwiftData

@Model
public final class StreakState {
    public var currentStreak: Int = 0
    public var longestStreak: Int = 0
    public var lastActiveDate: Date? = nil
    /// Last calendar date when exercises were due. Used to distinguish rest days from skipped
    /// training days when evaluating streak continuity.
    public var lastDueDate: Date? = nil

    public init(currentStreak: Int = 0, longestStreak: Int = 0, lastActiveDate: Date? = nil, lastDueDate: Date? = nil) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastActiveDate = lastActiveDate
        self.lastDueDate = lastDueDate
    }
}
