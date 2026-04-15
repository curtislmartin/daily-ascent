import SwiftUI
import SwiftData
import InchShared

struct ExerciseDetailView: View {
    let enrolmentId: PersistentIdentifier

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var enrolment: ExerciseEnrolment?
    @State private var detailViewModel = ExerciseDetailViewModel()
    @State private var showingUnenrolConfirm = false
    @State private var showingResetLevelConfirm = false
    @State private var pendingLevel: Int?
    @State private var pendingDay: Int?
    @State private var previewLevel: LevelDefinition?

    var body: some View {
        Group {
            if let enrolment {
                content(enrolment: enrolment)
            } else {
                ProgressView()
            }
        }
        .sheet(item: $previewLevel) { levelDef in
            LevelPreviewSheet(
                levelDefinition: levelDef,
                countingMode: enrolment?.exerciseDefinition?.countingMode ?? .postSetConfirmation,
                exerciseName: enrolment?.exerciseDefinition?.name ?? "Exercise",
                exerciseId: enrolment?.exerciseDefinition?.exerciseId ?? ""
            )
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            load()
            detailViewModel.load(enrolmentId: enrolmentId, context: modelContext)
        }
        .alert(
            pendingLevel == 0 ? "Jump to Prepare?" : "Jump to Level \(pendingLevel ?? 0)?",
            isPresented: Binding(get: { pendingLevel != nil }, set: { if !$0 { pendingLevel = nil } })
        ) {
            Button("Change Level") { applyLevelChange() }
            Button("Cancel", role: .cancel) { pendingLevel = nil }
        } message: {
            Text("Day resets to 1 and you'll train from the start of this level.")
        }
        .alert(
            "Jump to Day \(pendingDay ?? 0)?",
            isPresented: Binding(get: { pendingDay != nil }, set: { if !$0 { pendingDay = nil } })
        ) {
            Button("Change Day") { applyDayChange() }
            Button("Cancel", role: .cancel) { pendingDay = nil }
        } message: {
            Text("Your next session will be Day \(pendingDay ?? 0).")
        }
        .alert(
            "Reset to Day 1?",
            isPresented: $showingResetLevelConfirm
        ) {
            Button("Reset", role: .destructive) { resetCurrentLevel() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your current level stays the same, but you'll restart from Day 1.")
        }
        .alert(
            "Unenrol from this exercise?",
            isPresented: $showingUnenrolConfirm
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

        let accentColor = Color(hex: def?.color ?? "") ?? .accentColor

        return List {
            levelProgressSection(enrolment: enrolment)

            if !detailViewModel.sessionHistory.isEmpty {
                Section("History") {
                    SessionHistoryChart(
                        history: detailViewModel.sessionHistory,
                        testTarget: detailViewModel.testTarget,
                        accentColor: accentColor
                    )
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                }
            }

            Section("\(enrolment.currentLevel == 0 ? "Prepare" : "Level \(enrolment.currentLevel)") — \(days.count) days") {
                ForEach(days, id: \.dayNumber) { day in
                    let scheduled = detailViewModel.upcomingSchedule.first(where: { $0.dayNumber == day.dayNumber })?.scheduledDate
                    DayRow(
                        day: day,
                        status: dayStatus(day: day, enrolment: enrolment),
                        scheduledDate: scheduled,
                        countingMode: def?.countingMode ?? .postSetConfirmation
                    ) {
                        if day.dayNumber != enrolment.currentDay {
                            pendingDay = day.dayNumber
                        }
                    }
                }
            }

            Section {
                Button("Reset to Day 1") {
                    showingResetLevelConfirm = true
                }
                Button("Unenrol", role: .destructive) {
                    showingUnenrolConfirm = true
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(def?.name ?? "Exercise")
    }

    private func levelProgressSection(enrolment: ExerciseEnrolment) -> some View {
        let def = enrolment.exerciseDefinition
        let sortedLevels = (def?.levels ?? []).sorted { $0.level < $1.level }
        return Section {
            HStack(spacing: 0) {
                ForEach(sortedLevels, id: \.level) { levelDef in
                    levelSegment(
                        level: levelDef.level,
                        currentLevel: enrolment.currentLevel,
                        isActive: enrolment.isActive,
                        variationName: levelDef.variationName
                    )
                    .contextMenu {
                        Button {
                            previewLevel = levelDef
                        } label: {
                            Label("Preview Level", systemImage: "eye")
                        }
                    }
                    if levelDef.level < (sortedLevels.last?.level ?? 3) {
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
        } footer: {
            Text("Tap to jump. Long press to preview.")
                .font(.caption2)
        }
    }

    private func levelSegment(level: Int, currentLevel: Int, isActive: Bool, variationName: String?) -> some View {
        let isCurrent = level == currentLevel
        let isPast = level < currentLevel || !isActive

        return Button {
            pendingLevel = level
        } label: {
            VStack(spacing: 4) {
                Circle()
                    .fill(isPast ? Color.green : isCurrent ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading) {
                    Text(level == 0 ? "Prepare" : "Level \(level)")
                        .font(.headline)
                    if let variation = variationName {
                        Text(variation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(isCurrent)
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

    private func applyLevelChange() {
        guard let level = pendingLevel, let enrolment else { return }
        enrolment.currentLevel = level
        enrolment.currentDay = 1
        enrolment.nextScheduledDate = .now
        enrolment.restPatternIndex = 0
        try? modelContext.save()
        pendingLevel = nil
    }

    private func applyDayChange() {
        guard let day = pendingDay, let enrolment else { return }
        enrolment.currentDay = day
        enrolment.nextScheduledDate = .now
        try? modelContext.save()
        pendingDay = nil
    }

    private func resetCurrentLevel() {
        guard let enrolment else { return }
        enrolment.currentDay = 1
        enrolment.nextScheduledDate = .now
        enrolment.restPatternIndex = 0
        try? modelContext.save()
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
    var scheduledDate: Date? = nil
    var countingMode: CountingMode = .postSetConfirmation
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
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
                    if !day.sets.isEmpty {
                        if day.isTest, countingMode == .timed {
                            Text("Test — hold as long as you can")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        } else if !day.isTest {
                            Text(setSummary(day))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                Spacer()
                if let date = scheduledDate {
                    Text(date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(status == .current)
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

    private func setSummary(_ day: DayPrescription) -> String {
        if countingMode == .timed {
            let targetSeconds = day.sets.first ?? 0
            return "\(day.sets.count) sets · \(targetSeconds)s hold"
        }
        return "\(day.sets.count) sets · \(day.sets.map(String.init).joined(separator: "-")) reps"
    }
}
