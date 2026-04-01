import Testing
@testable import InchShared

struct AnalyticsUserSettingsTests {

    @Test func isFirstLaunchDefaultsTrue() {
        let settings = UserSettings()
        #expect(settings.isFirstLaunch == true)
    }

    @Test func analyticsEnabledDefaultsTrue() {
        let settings = UserSettings()
        #expect(settings.analyticsEnabled == true)
    }
}
