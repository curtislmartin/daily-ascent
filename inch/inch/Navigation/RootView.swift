import SwiftUI
import SwiftData
import InchShared

struct RootView: View {
    @Query private var settings: [UserSettings]
    @State private var onboardingComplete = false
    @Environment(AnalyticsService.self) private var analytics
    @Environment(\.scenePhase) private var scenePhase

    private var preferredColorScheme: ColorScheme? {
        switch settings.first?.appearanceMode {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }

    var body: some View {
        Group {
            if !onboardingComplete && settings.first?.onboardingComplete != true {
                OnboardingCoordinatorView { onboardingComplete = true }
            } else {
                AppTabView()
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .onChange(of: settings) {
            if settings.isEmpty { onboardingComplete = false }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                let appVersion = Bundle.main.object(
                    forInfoDictionaryKey: "CFBundleShortVersionString"
                ) as? String ?? ""
                analytics.record(AnalyticsEvent(
                    name: "app_opened",
                    properties: .appOpened(appVersion: appVersion)
                ))
            } else if newPhase == .background {
                analytics.persistQueue()
            }
        }
    }
}
