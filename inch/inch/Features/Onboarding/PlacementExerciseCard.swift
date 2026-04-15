import SwiftUI
import InchShared

struct PlacementExerciseCard: View {
    let definition: ExerciseDefinition
    @Bindable var viewModel: EnrolmentViewModel

    @State private var isExpanded = false
    @State private var testRepCount: Int = 0

    private var chosenLevel: Int {
        if let explicit = viewModel.levelChoices[definition.exerciseId] {
            return explicit
        }
        let hasFoundation = (definition.levels ?? []).contains { $0.level == 0 }
        return (definition.exerciseId == "pull_ups" && hasFoundation) ? 0 : 1
    }

    private var sortedLevels: [LevelDefinition] {
        (definition.levels ?? []).sorted { $0.level < $1.level }
    }

    private var accentColor: Color {
        Color(hex: definition.color) ?? .accentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            if isExpanded {
                Divider()
                VStack(alignment: .leading, spacing: 16) {
                    levelPicker
                    Divider()
                    placementTestSection
                }
                .padding()
            }
        }
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var headerRow: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            HStack {
                Circle()
                    .fill(accentColor)
                    .frame(width: 10, height: 10)
                Text(definition.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text(chosenLevel == 0 ? "Prepare" : "Level \(chosenLevel)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding()
    }

    private var levelPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose a starting level")
                .font(.subheadline)
                .fontWeight(.medium)
            ForEach(sortedLevels, id: \.level) { levelDef in
                levelRow(for: levelDef)
            }
        }
    }

    private func levelRow(for levelDef: LevelDefinition) -> some View {
        let day1Sets = (levelDef.days ?? [])
            .sorted { $0.dayNumber < $1.dayNumber }
            .first?.sets ?? []
        let setsFormatted = day1Sets.map { "\($0)" }.joined(separator: ", ")
        let isChosen = chosenLevel == levelDef.level

        return Button {
            viewModel.levelChoices[definition.exerciseId] = levelDef.level
        } label: {
            HStack(alignment: .top) {
                Image(systemName: isChosen ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isChosen ? accentColor : .secondary)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(levelDef.level == 0 ? "Prepare" : "Level \(levelDef.level)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    if let variation = levelDef.variationName {
                        Text(variation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !setsFormatted.isEmpty {
                        Text("Day 1: \(setsFormatted) reps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("Test target: \(levelDef.testTarget) reps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }

    private var placementTestSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Or take a placement test")
                .font(.subheadline)
                .fontWeight(.medium)
            Text("Do as many \(definition.name) as you can in one set, then enter your count below.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Text("Reps completed:")
                    .font(.subheadline)
                Spacer()
                Stepper(value: $testRepCount, in: 0...999) {
                    Text("\(testRepCount)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .monospacedDigit()
                        .frame(minWidth: 36, alignment: .trailing)
                }
            }
            if testRepCount > 0 {
                recommendationView
            }
        }
    }

    private var recommendationView: some View {
        let targets = sortedLevels.map { $0.testTarget }
        let levelNumbers = sortedLevels.map { $0.level }
        let recommended = EnrolmentViewModel.recommendLevel(score: testRepCount, testTargets: targets, levels: levelNumbers)
        let isApplied = chosenLevel == recommended

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                Text("We recommend \(recommended == 0 ? "Prepare" : "Level \(recommended)")")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            if !isApplied {
                Button("Start at \(recommended == 0 ? "Prepare" : "Level \(recommended)")") {
                    viewModel.levelChoices[definition.exerciseId] = recommended
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                Text("Applied ✓")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}
