import SwiftUI

struct ExerciseSummaryRow: View {
    let exercise: HistoryViewModel.ExerciseSummary
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let accentColor = Color(hex: exercise.color) ?? .accentColor
        let allTargetsHit = exercise.actualReps >= exercise.targetReps

        HStack(spacing: 10) {
            Circle()
                .fill(accentColor)
                .frame(width: 8, height: 8)

            Text(exercise.exerciseName)
                .font(.subheadline)
                .lineLimit(1)

            Text("L\(exercise.level) D\(exercise.dayNumber)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            Text("\(exercise.setCount) sets")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("\(exercise.actualReps)/\(exercise.targetReps)")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(allTargetsHit ? .primary : .secondary)

            if allTargetsHit {
                Image(systemName: "checkmark")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.green)
            }
        }
    }
}
