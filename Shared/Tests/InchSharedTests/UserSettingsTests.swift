import Testing
@testable import InchShared

struct UserSettingsTests {

    @Test func hasDemographicsReturnsFalseWhenAllNil() {
        let settings = UserSettings()
        #expect(settings.hasDemographics == false)
    }

    @Test func hasDemographicsReturnsFalseWhenPartial() {
        let settings = UserSettings(ageRange: "30–39")
        #expect(settings.hasDemographics == false)
    }

    @Test func hasDemographicsReturnsTrueWhenAllSet() {
        let settings = UserSettings(
            ageRange: "30–39",
            heightRange: "171–180cm",
            biologicalSex: "Male",
            activityLevel: "Intermediate"
        )
        #expect(settings.hasDemographics)
    }

    @Test func onboardingCompleteDefaultsFalse() {
        let settings = UserSettings()
        #expect(settings.onboardingComplete == false)
    }
}
