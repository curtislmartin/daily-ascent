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
        case consent
    }

    var body: some View {
        Group {
            switch step {
            case .enrolment:
                EnrolmentView(viewModel: viewModel) {
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
