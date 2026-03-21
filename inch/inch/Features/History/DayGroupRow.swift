import SwiftUI

struct DayGroupRow: View {
    let day: HistoryViewModel.DayGroup
    @State private var isExpanded = false

    private var dayLabel: String {
        day.id.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    private var durationLabel: String? {
        guard let duration = day.duration else { return nil }
        let minutes = Int(duration / 60)
        return minutes > 0 ? "\(minutes) min" : nil
    }

    var body: some View {
        if day.isTestDay {
            testDayContent
        } else {
            regularDayContent
        }
    }

    @ViewBuilder
    private var regularDayContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(dayLabel)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("\(day.totalReps) reps")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 4) {
                            exerciseDots
                            Text("·")
                                .foregroundStyle(.secondary)
                            Text("\(day.exercises.count) exercises")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let dur = durationLabel {
                                Text("·")
                                    .foregroundStyle(.secondary)
                                Text(dur)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(collapsedLabel)
            .accessibilityHint(isExpanded ? "Double-tap to collapse" : "Double-tap to expand")

            if isExpanded {
                Divider()
                    .padding(.vertical, 8)
                ForEach(day.exercises) { exercise in
                    ExerciseSummaryRow(exercise: exercise)
                        .padding(.vertical, 2)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var testDayContent: some View {
        ForEach(day.exercises.filter(\.isTest)) { exercise in
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if exercise.testPassed == true {
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                    }
                    Text("\(dayLabel) — \(exercise.exerciseName) Test")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                let outcome: String = {
                    if let passed = exercise.testPassed {
                        return passed
                            ? "Level \(exercise.level) Final — \(exercise.actualReps) / \(exercise.targetReps) — PASSED"
                            : "Level \(exercise.level) Final — \(exercise.actualReps) / \(exercise.targetReps) — Retry next"
                    }
                    return "Level \(exercise.level) Final — \(exercise.actualReps) / \(exercise.targetReps)"
                }()
                Text(outcome)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private var exerciseDots: some View {
        HStack(spacing: 3) {
            ForEach(day.exercises) { exercise in
                Circle()
                    .fill(Color(hex: exercise.color) ?? .accentColor)
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityHidden(true)
    }

    private var collapsedLabel: String {
        var parts = [dayLabel, "\(day.totalReps) reps", "\(day.exercises.count) exercises"]
        if let dur = durationLabel { parts.append(dur) }
        return parts.joined(separator: ", ")
    }
}
