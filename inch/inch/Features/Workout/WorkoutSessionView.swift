import SwiftUI
import SwiftData
import InchShared

struct WorkoutSessionView: View {
    let enrolmentId: PersistentIdentifier

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(HealthKitService.self) private var healthKit
    @Environment(MotionRecordingService.self) private var motionRecording

    @Query private var allSettings: [UserSettings]
    private var sensorConsented: Bool { allSettings.first?.motionDataUploadConsented ?? false }

    @State private var viewModel: WorkoutViewModel
    @State private var pendingRecordingURL: URL?

    init(enrolmentId: PersistentIdentifier) {
        self.enrolmentId = enrolmentId
        _viewModel = State(initialValue: WorkoutViewModel(enrolmentId: enrolmentId))
    }

    var body: some View {
        Group {
            switch viewModel.phase {
            case .loading:
                ProgressView()
            case .ready:
                readyView
            case .inSet:
                inSetView
            case .confirming(let targetReps, let duration):
                PostSetConfirmationView(targetReps: targetReps, duration: duration) { actual in
                    let url = pendingRecordingURL
                    pendingRecordingURL = nil
                    viewModel.confirmSet(actual: actual, context: modelContext, recordingURL: url)
                }
            case .resting(let seconds):
                RestTimerView(totalSeconds: seconds) {
                    viewModel.finishRest()
                }
            case .complete:
                ExerciseCompleteView(
                    exerciseName: viewModel.exerciseName,
                    totalReps: viewModel.sessionTotalReps,
                    nextDate: viewModel.enrolment?.nextScheduledDate,
                    onDone: { dismiss() }
                )
            }
        }
        .navigationTitle(viewModel.exerciseName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.load(context: modelContext)
            await healthKit.requestAuthorization()
        }
        .onChange(of: viewModel.phase) { _, newPhase in
            switch newPhase {
            case .inSet:
                if sensorConsented {
                    let exerciseId = viewModel.enrolment?.exerciseDefinition?.exerciseId ?? ""
                    motionRecording.startRecording(exerciseId: exerciseId, setNumber: viewModel.currentSetIndex + 1)
                }
            case .confirming:
                if motionRecording.isRecording {
                    pendingRecordingURL = motionRecording.stopRecording()
                }
            case .complete:
                let start = viewModel.sessionDate
                let exerciseId = viewModel.enrolment?.exerciseDefinition?.exerciseId ?? ""
                Task {
                    await healthKit.saveWorkout(
                        startDate: start,
                        endDate: .now,
                        totalEnergyBurned: nil,
                        metadata: ["exerciseId": exerciseId]
                    )
                }
            default:
                break
            }
        }
    }

    private var readyView: some View {
        VStack(spacing: 32) {
            setProgressHeader

            Spacer()

            VStack(spacing: 16) {
                Text("\(viewModel.currentTargetReps)")
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                Text("target reps")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if viewModel.countingMode == .realTime {
                RealTimeCountingView(
                    targetReps: viewModel.currentTargetReps
                ) { actual in
                    viewModel.completeRealTimeSet(actual: actual, context: modelContext)
                }
            } else {
                Button("Start Set \(viewModel.currentSetIndex + 1)") {
                    viewModel.startSet()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding()
    }

    private var inSetView: some View {
        VStack(spacing: 32) {
            setProgressHeader

            Spacer()

            VStack(spacing: 8) {
                Text("Set in progress…")
                    .font(.title2)
                    .fontWeight(.semibold)
                ElapsedTimerView()
            }

            Spacer()

            Button("Done with Set") {
                viewModel.endSet()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }

    private var setProgressHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Set \(viewModel.currentSetIndex + 1) of \(viewModel.totalSets)")
                    .font(.headline)
                Text("Day \(viewModel.enrolment?.currentDay ?? 0) · Level \(viewModel.enrolment?.currentLevel ?? 0)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let next = viewModel.prescription?.sets[safe: viewModel.currentSetIndex + 1] {
                Text("Next: \(next) reps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
