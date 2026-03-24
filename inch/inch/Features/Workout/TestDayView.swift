import SwiftUI
import SwiftData
import InchShared

private enum TestPhase: Equatable {
    case ready
    case counting(reps: Int)
    case result(reps: Int, passed: Bool, nextDate: Date?)
}

struct TestDayView: View {
    let enrolmentId: PersistentIdentifier

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Environment(NotificationService.self) private var notifications
    @Query private var allSettings: [UserSettings]
    private var settings: UserSettings? { allSettings.first }

    @State private var enrolment: ExerciseEnrolment?
    @State private var testTarget: Int = 0
    @State private var phase: TestPhase = .ready
    private let scheduler = SchedulingEngine()

    var body: some View {
        Group {
            switch phase {
            case .ready:
                readyView
            case .counting(let reps):
                countingView(reps: reps)
            case .result(let reps, let passed, let nextDate):
                resultView(reps: reps, passed: passed, nextDate: nextDate)
            }
        }
        .navigationTitle("Test Day")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task { load() }
        .onChange(of: phase) { _, newPhase in
            guard case .result(_, let passed, _) = newPhase,
                  let settings else { return }
            Task {
                await notifications.requestPermission()
                await notifications.refresh(context: modelContext, settings: settings)
                if passed, settings.levelUnlockNotificationEnabled,
                   let enrolment {
                    notifications.postLevelUnlock(
                        exerciseName: enrolment.exerciseDefinition?.name ?? "",
                        newLevel: enrolment.currentLevel,
                        startsIn: SchedulingEngine.interLevelGapDays
                    )
                }
            }
        }
    }

    private var readyView: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Text("Test Day")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Do as many reps as you can.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Target to pass: \(testTarget)")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.orange.opacity(0.12), in: Capsule())
                    .foregroundStyle(.orange)
            }

            Spacer()

            RealTimeCountingView(targetReps: testTarget, autoCompleteAtTarget: false) { actual in
                phase = .counting(reps: actual)
                finishTest(reps: actual)
            }
        }
        .padding()
    }

    private func countingView(reps: Int) -> some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
        }
    }

    private func resultView(reps: Int, passed: Bool, nextDate: Date?) -> some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: passed ? "trophy.fill" : "arrow.clockwise.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(passed ? .yellow : .orange)

                Text(passed ? "Level Up!" : "Good Effort")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("\(reps) reps — target was \(testTarget)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !passed {
                    Text("Keep training. You'll get there.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            if let next = nextDate {
                VStack(spacing: 4) {
                    Text("Next session")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(next.formatted(.relative(presentation: .named)).lowercased())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .navigationBarBackButtonHidden()
    }

    private func load() {
        let enrolment: ExerciseEnrolment? = modelContext.registeredModel(for: enrolmentId)
            ?? fetchEnrolment()
        guard let enrolment else { return }
        self.enrolment = enrolment
        let levelDef = enrolment.exerciseDefinition?
            .levels?
            .first(where: { $0.level == enrolment.currentLevel })
        testTarget = levelDef?.testTarget ?? 0
    }

    private func finishTest(reps: Int) {
        guard let enrolment,
              let def = enrolment.exerciseDefinition,
              let levelDef = def.levels?.first(where: { $0.level == enrolment.currentLevel })
        else { return }

        let passed = reps >= testTarget
        let sessionDate = Date.now

        let completedSet = CompletedSet(
            sessionDate: sessionDate,
            exerciseId: def.exerciseId,
            level: enrolment.currentLevel,
            dayNumber: enrolment.currentDay,
            setNumber: 1,
            targetReps: testTarget,
            actualReps: reps,
            isTest: true,
            testPassed: passed,
            countingMode: .realTime
        )
        completedSet.enrolment = enrolment
        modelContext.insert(completedSet)

        let snapshot = EnrolmentSnapshot(enrolment)
        let levelSnap = LevelSnapshot(levelDef)
        let updated = scheduler.applyCompletion(
            to: snapshot,
            level: levelSnap,
            actualDate: sessionDate,
            totalReps: reps
        )
        let nextDate = scheduler.computeNextDate(enrolment: updated, level: levelSnap)
        scheduler.writeBack(updated, to: enrolment, nextDate: nextDate)
        try? modelContext.save()

        phase = .result(reps: reps, passed: passed, nextDate: nextDate)
    }

    private func fetchEnrolment() -> ExerciseEnrolment? {
        let all = (try? modelContext.fetch(FetchDescriptor<ExerciseEnrolment>())) ?? []
        return all.first(where: { $0.persistentModelID == enrolmentId })
    }
}
