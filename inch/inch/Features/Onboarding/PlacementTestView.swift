import SwiftUI
import SwiftData
import InchShared

struct PlacementTestView: View {
    @Query private var definitions: [ExerciseDefinition]

    @Bindable var viewModel: EnrolmentViewModel
    var onContinue: () -> Void

    private var selectedDefinitions: [ExerciseDefinition] {
        definitions
            .filter { viewModel.selectedExerciseIds.contains($0.exerciseId) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("For each exercise, choose where to begin. You can adjust this any time.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)

                    ForEach(selectedDefinitions, id: \.exerciseId) { definition in
                        PlacementExerciseCard(
                            definition: definition,
                            viewModel: viewModel
                        )
                    }

                    continueButton
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationTitle("Starting Level")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var continueButton: some View {
        Button {
            onContinue()
        } label: {
            Text("Continue")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .padding(.top, 8)
    }
}
