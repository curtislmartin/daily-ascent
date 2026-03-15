import SwiftUI
import SwiftData
import InchShared

struct OnboardingCoordinatorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var definitions: [ExerciseDefinition]

    @State private var step: Step = .enrolment
    @State private var viewModel = EnrolmentViewModel()

    private enum Step {
        case enrolment
        case placement
        case consent
    }

    var body: some View {
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
                DataConsentView()
            }
        }
        .task {
            if definitions.isEmpty {
                let loader = ExerciseDataLoader()
                try? loader.seedIfNeeded(context: modelContext)
            }
        }
    }
}
