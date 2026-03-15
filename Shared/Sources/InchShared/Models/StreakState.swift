import Foundation
import SwiftData

@Model
public final class StreakState {
    public var currentStreak: Int = 0
    public var longestStreak: Int = 0
    public var lastActiveDate: Date? = nil

    public init(currentStreak: Int = 0, longestStreak: Int = 0, lastActiveDate: Date? = nil) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastActiveDate = lastActiveDate
    }
}
