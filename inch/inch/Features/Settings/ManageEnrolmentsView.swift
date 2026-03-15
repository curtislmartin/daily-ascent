import SwiftUI
import SwiftData
import InchShared

struct ManageEnrolmentsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var definitions: [ExerciseDefinition]
    @Query private var existingEnrolments: [ExerciseEnrolment]

    @State private var viewModel = EnrolmentViewModel()

    private var alreadyEnrolledIds: Set<String> {
        Set(existingEnrolments.compactMap { $0.exerciseDefinition?.exerciseId })
    }

    private var availableDefinitions: [ExerciseDefinition] {
        definitions.filter { !alreadyEnrolledIds.contains($0.exerciseId) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if availableDefinitions.isEmpty {
                    allEnrolledView
                } else {
                    exerciseSections
                    startDateSection
                    addButton
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .navigationTitle("Add Programs")
        .navigationBarTitleDisplayMode(.large)
    }

    private var allEnrolledView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("You're enrolled in all available exercises.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var selectAllButton: some View {
        let ids = availableDefinitions.map { $0.exerciseId }
        let allSelected = viewModel.selectedExerciseIds.count == ids.count && !ids.isEmpty
        return Button(allSelected ? "Deselect All" : "Select All") {
            if allSelected {
                viewModel.selectedExerciseIds = []
            } else {
                viewModel.selectAll(ids: ids)
            }
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    @ViewBuilder
    private var exerciseSections: some View {
        selectAllButton
        ForEach(viewModel.sections(from: availableDefinitions), id: \.label) { section in
            VStack(alignment: .leading, spacing: 12) {
                Text(section.label)
                    .font(.headline)

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

    private var startDateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Start Date")
                .font(.headline)
            DatePicker(
                "Start Date",
                selection: $viewModel.startDate,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
        }
    }

    private var addButton: some View {
        Button {
            try? viewModel.saveEnrolments(from: availableDefinitions, context: modelContext)
            dismiss()
        } label: {
            Text("Add Program")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.canProceed)
    }
}
