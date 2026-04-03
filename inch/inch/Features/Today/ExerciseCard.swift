import SwiftUI
import SwiftData
import InchShared

struct ExerciseCard: View {
    let enrolment: ExerciseEnrolment
    let prescription: DayPrescription?
    let conflictWarning: String?
    var isCompleted: Bool = false
    var isInProgress: Bool = false

    private var definition: ExerciseDefinition? { enrolment.exerciseDefinition }
    private var isTestDay: Bool { prescription?.isTest ?? false }

    private var destination: WorkoutDestination {
        isTestDay
            ? .testDay(enrolment.persistentModelID)
            : .exercise(enrolment.persistentModelID)
    }

    var body: some View {
        NavigationLink(value: destination) {
            VStack(alignment: .leading, spacing: 0) {
                if let warning = conflictWarning, !isCompleted {
                    conflictBanner(warning)
                }
                cardContent
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(accentColor.opacity(0.3), lineWidth: 1)
            )
            .opacity(isCompleted ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isCompleted)
        .accessibilityLabel(cardAccessibilityLabel)
    }

    private var cardContent: some View {
        HStack(alignment: .center, spacing: 14) {
            colorBar
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(definition?.name ?? "Exercise")
                        .font(.body)
                        .fontWeight(.semibold)
                    if isTestDay {
                        testDayBadge
                    }
                    Spacer()
                    levelBadge
                }
                HStack(spacing: 6) {
                    if let summary = setSummary {
                        Text(summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let group = definition?.muscleGroup {
                        muscleGroupTag(group)
                    }
                }
                HStack(spacing: 6) {
                    Text("Day \(enrolment.currentDay)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    if isInProgress {
                        Text("In progress")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.1), in: Capsule())
                            .foregroundStyle(.blue)
                    }
                }
            }
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
                    .accessibilityLabel("Completed")
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(14)
    }

    private var colorBar: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(accentColor)
            .frame(width: 4)
            .frame(height: 52)
            .accessibilityHidden(true)
    }

    private var testDayBadge: some View {
        Text("TEST DAY")
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.orange.opacity(0.15), in: Capsule())
            .foregroundStyle(.orange)
            .accessibilityLabel("Test day")
    }

    private var levelBadge: some View {
        Text("L\(enrolment.currentLevel)")
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.secondary.opacity(0.12), in: Capsule())
            .foregroundStyle(.secondary)
            .accessibilityLabel("Level \(enrolment.currentLevel)")
    }

    private func conflictBanner(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
            Text(message)
                .font(.caption)
        }
        .foregroundStyle(.orange)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.orange.opacity(0.08))
    }

    private var setSummary: String? {
        guard let prescription, !prescription.sets.isEmpty else { return nil }
        let repsStr = prescription.sets.map(String.init).joined(separator: "-")
        return "\(prescription.sets.count) sets · \(repsStr) reps"
    }

    private func muscleGroupTag(_ group: MuscleGroup) -> some View {
        Text(group.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(accentColor.opacity(0.1), in: Capsule())
            .foregroundStyle(accentColor)
            .accessibilityHidden(true)
    }

    private var cardAccessibilityLabel: String {
        var parts: [String] = []
        parts.append(definition?.name ?? "Exercise")
        if isTestDay { parts.append("Test day") }
        parts.append("Level \(enrolment.currentLevel), day \(enrolment.currentDay)")
        if let summary = setSummary { parts.append(summary) }
        if let warning = conflictWarning { parts.append("Warning: \(warning)") }
        if isCompleted { parts.append("Completed") }
        if isInProgress { parts.append("In progress") }
        return parts.joined(separator: ", ")
    }

    private var accentColor: Color {
        Color(hex: definition?.color ?? "") ?? .accentColor
    }
}

