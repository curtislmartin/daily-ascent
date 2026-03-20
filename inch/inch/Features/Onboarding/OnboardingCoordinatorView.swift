import SwiftUI
import SwiftData
import InchShared

struct OnboardingCoordinatorView: View {
    let onComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query private var definitions: [ExerciseDefinition]

    @State private var step: Step = .enrolment
    @State private var viewModel = EnrolmentViewModel()
    @State private var consented = false

    private enum Step {
        case enrolment
        case placement
        case consent
        case demographics
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .enrolment:
                    EnrolmentView(viewModel: viewModel) {
                        step = .placement
                    }
                case .placement:
                    PlacementTestView(viewModel: viewModel) {
                        try? viewModel.saveEnrolments(from: definitions, context: modelContext)
                        step = .consent
                    }
                case .consent:
                    DataConsentView { didConsent in
                        consented = didConsent
                        step = .demographics
                    }
                case .demographics:
                    DemographicTagsView { ageRange, heightRange, biologicalSex, activityLevel in
                        saveSettings(
                            ageRange: ageRange,
                            heightRange: heightRange,
                            biologicalSex: biologicalSex,
                            activityLevel: activityLevel
                        )
                    }
                }
            }
        }
        .task {
            if definitions.isEmpty {
                let loader = ExerciseDataLoader()
                try? loader.seedIfNeeded(context: modelContext)
            }
        }
    }

    private func saveSettings(
        ageRange: String?,
        heightRange: String?,
        biologicalSex: String?,
        activityLevel: String?
    ) {
        let settings = UserSettings(
            motionDataUploadConsented: consented,
            consentDate: consented ? .now : nil,
            contributorId: consented ? UUID().uuidString.lowercased() : "",
            ageRange: ageRange,
            heightRange: heightRange,
            biologicalSex: biologicalSex,
            activityLevel: activityLevel,
            onboardingComplete: true
        )
        let streakState = StreakState()
        modelContext.insert(settings)
        modelContext.insert(streakState)
        try? modelContext.save()
        onComplete()
    }
}
