import SwiftUI
import SwiftData
import InchShared

struct RootView: View {
    @Query private var settings: [UserSettings]
    @State private var onboardingComplete = false

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
    }
}
