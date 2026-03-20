import SwiftUI
import SwiftData
import InchShared

struct EnrolmentView: View {
    @Query private var definitions: [ExerciseDefinition]

    @Bindable var viewModel: EnrolmentViewModel
    var onEnrolmentSaved: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    exerciseSections
                    balanceNudge
                    startButton
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationTitle("Choose Your Programs")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var headerSection: some View {
        HStack {
            Text("Select the exercises you want to train. You can add more later.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Button(viewModel.selectedExerciseIds.count == definitions.count ? "Deselect All" : "Select All") {
                if viewModel.selectedExerciseIds.count == definitions.count {
                    viewModel.selectedExerciseIds = []
                } else {
                    viewModel.selectAll(ids: definitions.map { $0.exerciseId })
                }
            }
            .font(.subheadline)
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var exerciseSections: some View {
        let sections = viewModel.sections(from: definitions)
        if sections.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else {
            ForEach(sections, id: \.label) { section in
                VStack(alignment: .leading, spacing: 12) {
                    Text(section.label)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    ForEach(section.definitions, id: \.exerciseId) { definition in
                        ExerciseSelectionCard(
                            definition: definition,
                            isSelected: viewModel.isSelected(definition.exerciseId)
                        ) {
                            viewModel.toggle(definition.exerciseId)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var balanceNudge: some View {
        if viewModel.selectedExerciseIds.count == 1 {
            Text("Tip: Adding exercises from different muscle groups gives you a more balanced program.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(12)
                .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var startButton: some View {
        Button {
            saveAndContinue()
        } label: {
            Text("Start Program")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.canProceed)
    }

    private func saveAndContinue() {
        onEnrolmentSaved()
    }
}
