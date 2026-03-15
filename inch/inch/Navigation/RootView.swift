import SwiftUI
import SwiftData
import InchShared

struct RootView: View {
    @Query private var settings: [UserSettings]

    var body: some View {
        if settings.isEmpty {
            OnboardingCoordinatorView()
        } else {
            AppTabView()
        }
    }
}
