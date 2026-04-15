import SwiftUI
import InchShared

struct LevelPreviewSheet: View {
    let levelDefinition: LevelDefinition
    let countingMode: CountingMode
    let exerciseName: String
    var exerciseId: String = ""

    private var sortedDays: [DayPrescription] {
        (levelDefinition.days ?? []).sorted { $0.dayNumber < $1.dayNumber }
    }

    private var levelLabel: String {
        levelDefinition.level == 0 ? "Prepare" : "Level \(levelDefinition.level)"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let variation = levelDefinition.variationName {
                        LabeledContent("Variation", value: variation)
                    }
                    if let info = ExerciseContent.info(exerciseId: exerciseId, level: levelDefinition.level) {
                        Text(info.movement)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("Training Days", value: "\(levelDefinition.totalDays)")
                    LabeledContent("Test Target", value: "\(levelDefinition.testTarget) \(countingMode == .timed ? "seconds" : "reps")")
                    LabeledContent("Rest Pattern", value: levelDefinition.restDayPattern.map(String.init).joined(separator: "-"))
                    if let extra = levelDefinition.extraRestBeforeTest {
                        LabeledContent("Extra Rest Before Test", value: "\(extra) days")
                    }
                }

                Section("Day-by-Day") {
                    ForEach(sortedDays, id: \.dayNumber) { day in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text("Day \(day.dayNumber)")
                                        .font(.body)
                                    if day.isTest {
                                        Text("TEST")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(.orange.opacity(0.15), in: Capsule())
                                            .foregroundStyle(.orange)
                                    }
                                }
                                if !day.isTest {
                                    Text(setSummary(day))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else if countingMode == .timed {
                                    Text("Hold as long as you can")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if !day.isTest {
                                Text("\(day.sets.reduce(0, +)) total")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("\(exerciseName) — \(levelLabel)")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func setSummary(_ day: DayPrescription) -> String {
        if countingMode == .timed {
            let targetSeconds = day.sets.first ?? 0
            return "\(day.sets.count) sets \u{00B7} \(targetSeconds)s hold"
        }
        return "\(day.sets.count) sets \u{00B7} \(day.sets.map(String.init).joined(separator: "-")) reps"
    }
}
