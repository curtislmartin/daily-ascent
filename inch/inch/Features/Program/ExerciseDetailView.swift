import SwiftUI
import SwiftData
import InchShared

struct ExerciseDetailView: View {
    let enrolmentId: PersistentIdentifier

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var enrolment: ExerciseEnrolment?
    @State private var showingUnenrolConfirm = false

    var body: some View {
        Group {
            if let enrolment {
                content(enrolment: enrolment)
            } else {
                ProgressView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { load() }
        .confirmationDialog(
            "Unenrol from this exercise?",
            isPresented: $showingUnenrolConfirm,
            titleVisibility: .visible
        ) {
            Button("Unenrol", role: .destructive) { unenrol() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your progress will be saved and you can re-enrol later.")
        }
    }

    private func content(enrolment: ExerciseEnrolment) -> some View {
        let def = enrolment.exerciseDefinition
        let levelDef = def?.levels?.first(where: { $0.level == enrolment.currentLevel })
        let days = levelDef?.days?.sorted(by: { $0.dayNumber < $1.dayNumber }) ?? []

        return List {
            levelProgressSection(enrolment: enrolment)

            Section("Level \(enrolment.currentLevel) — \(days.count) days") {
                ForEach(days, id: \.dayNumber) { day in
                    DayRow(
                        day: day,
                        status: dayStatus(day: day, enrolment: enrolment)
                    )
                }
            }

            Section {
                Button("Unenrol", role: .destructive) {
                    showingUnenrolConfirm = true
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(def?.name ?? "Exercise")
    }

    private func levelProgressSection(enrolment: ExerciseEnrolment) -> some View {
        Section {
            HStack(spacing: 0) {
                ForEach(1...3, id: \.self) { level in
                    levelSegment(level: level, currentLevel: enrolment.currentLevel, isActive: enrolment.isActive)
                    if level < 3 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.vertical, 4)

            if let next = enrolment.nextScheduledDate {
                Label(
                    "Next: \(next.formatted(.relative(presentation: .named)))",
                    systemImage: "calendar"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func levelSegment(level: Int, currentLevel: Int, isActive: Bool) -> some View {
        let isCurrent = level == currentLevel
        let isPast = level < currentLevel || !isActive

        return VStack(spacing: 4) {
            Circle()
                .fill(isPast ? Color.green : isCurrent ? Color.accentColor : Color.secondary.opacity(0.3))
                .frame(width: 10, height: 10)
            Text("L\(level)")
                .font(.caption2)
                .fontWeight(isCurrent ? .bold : .regular)
                .foregroundStyle(isCurrent ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func dayStatus(day: DayPrescription, enrolment: ExerciseEnrolment) -> DayStatus {
        if day.dayNumber < enrolment.currentDay { return .completed }
        if day.dayNumber == enrolment.currentDay { return .current }
        return .upcoming
    }

    private func load() {
        let found: ExerciseEnrolment? = modelContext.registeredModel(for: enrolmentId)
        if let found {
            enrolment = found
        } else {
            let all = (try? modelContext.fetch(FetchDescriptor<ExerciseEnrolment>())) ?? []
            enrolment = all.first(where: { $0.persistentModelID == enrolmentId })
        }
    }

    private func unenrol() {
        enrolment?.isActive = false
        try? modelContext.save()
        dismiss()
    }
}

private enum DayStatus { case completed, current, upcoming }

private struct DayRow: View {
    let day: DayPrescription
    let status: DayStatus

    var body: some View {
        HStack(spacing: 12) {
            statusIcon
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Day \(day.dayNumber)")
                        .font(.body)
                        .foregroundStyle(status == .upcoming ? .secondary : .primary)
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
                if !day.sets.isEmpty, !day.isTest {
                    Text(setSummary(day.sets))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var statusIcon: some View {
        Group {
            switch status {
            case .completed:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            case .current:
                Image(systemName: "circle.fill").foregroundStyle(Color.accentColor)
            case .upcoming:
                Image(systemName: "circle").foregroundStyle(.quaternary)
            }
        }
        .font(.body)
    }

    private func setSummary(_ sets: [Int]) -> String {
        "\(sets.count) sets · \(sets.map(String.init).joined(separator: "-")) reps"
    }
}

