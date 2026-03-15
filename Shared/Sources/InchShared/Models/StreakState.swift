import Foundation
import SwiftData

@Model
final class StreakState {
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastActiveDate: Date? = nil

    init(currentStreak: Int = 0, longestStreak: Int = 0, lastActiveDate: Date? = nil) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastActiveDate = lastActiveDate
    }
}
