import SwiftUI
import SwiftData
import InchShared

struct RootView: View {
    @Query private var settings: [UserSettings]

    private var preferredColorScheme: ColorScheme? {
        switch settings.first?.appearanceMode {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }

    var body: some View {
        Group {
            if settings.first?.onboardingComplete != true {
                OnboardingCoordinatorView()
            } else {
                AppTabView()
            }
        }
        .preferredColorScheme(preferredColorScheme)
    }
}
