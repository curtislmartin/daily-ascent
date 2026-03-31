import Testing
@testable import InchShared

struct AchievementModelTests {

    @Test func defaultsToNotCelebrated() {
        let achievement = Achievement(
            id: "streak_7",
            category: "streak",
            unlockedAt: .now
        )
        #expect(achievement.wasCelebrated == false)
    }

    @Test func achievementNotificationEnabledDefaultsTrue() {
        let settings = UserSettings()
        #expect(settings.achievementNotificationEnabled == true)
    }
}
