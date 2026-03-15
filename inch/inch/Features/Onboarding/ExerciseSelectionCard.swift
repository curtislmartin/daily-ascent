import SwiftUI
import InchShared

struct ExerciseSelectionCard: View {
    let definition: ExerciseDefinition
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                selectionIndicator
                exerciseInfo
                Spacer()
                muscleGroupTag
            }
            .padding(16)
            .background(cardBackground)
            .overlay(cardBorder)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private var selectionIndicator: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title2)
            .foregroundStyle(isSelected ? Color.accentColor : .secondary)
    }

    private var exerciseInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(definition.name)
                .font(.body)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            Text(programLengthEstimate)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var muscleGroupTag: some View {
        Text(definition.muscleGroup.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.secondary.opacity(0.15), in: Capsule())
            .foregroundStyle(.secondary)
    }

    private var cardBackground: some ShapeStyle {
        isSelected ? AnyShapeStyle(Color.accentColor.opacity(0.08)) : AnyShapeStyle(Color(.secondarySystemGroupedBackground))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(
                isSelected ? Color.accentColor : Color.clear,
                lineWidth: 1.5
            )
    }

    private var programLengthEstimate: String {
        guard let levels = definition.levels, !levels.isEmpty else { return "Program" }
        let total = levels.reduce(0) { $0 + $1.totalDays }
        let weeks = max(1, total / 3)
        return "~\(weeks) weeks"
    }
}

private extension MuscleGroup {
    var displayName: String {
        switch self {
        case .upperPush: "Upper Push"
        case .upperPull: "Upper Pull"
        case .lower: "Lower"
        case .lowerPosterior: "Lower Post."
        case .coreFlexion: "Core"
        case .coreStability: "Core"
        }
    }
}
