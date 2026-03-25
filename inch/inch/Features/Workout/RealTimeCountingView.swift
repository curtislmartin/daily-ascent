import SwiftUI
import InchShared

struct RealTimeCountingView: View {
    let targetReps: Int
    var autoCompleteAtTarget: Bool = true
    var repCounter: RepCounter? = nil
    let onComplete: (Int) -> Void

    @State private var manualCount: Int = 0
    @State private var showingCompletion: Bool = false
    @State private var targetReached: Bool = false

    private var count: Int {
        repCounter?.count ?? manualCount
    }

    private var progress: Double {
        targetReps > 0 ? min(Double(count) / Double(targetReps), 1) : 0
    }

    private var ringColor: Color {
        targetReached ? .green : .accentColor
    }

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(.secondary.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 0.2), value: count)

                VStack(spacing: 2) {
                    Text("\(count)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    if repCounter != nil {
                        Text("auto")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 200, height: 200)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(count) reps\(repCounter != nil ? ", auto counted" : "")")

            if targetReached {
                Text("Target reached! Keep going.")
                    .font(.subheadline)
                    .foregroundStyle(.green)
                    .transition(.opacity.combined(with: .scale))
            } else {
                Text("target: \(targetReps)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if repCounter != nil {
                HStack(spacing: 20) {
                    Button {
                        adjustCount(by: -1)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove rep")

                    Button {
                        adjustCount(by: 1)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add rep")
                }

                Button("Done — \(count) reps") {
                    finish(reps: count)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(count == 0 || showingCompletion)
            } else {
                Button {
                    tapRep()
                } label: {
                    Text("Tap Each Rep")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(showingCompletion)
                .accessibilityHint("Double-tap to count one rep")

                if count > 0 {
                    Button("Done — \(count) reps") {
                        finish(reps: count)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
            }
        }
        .animation(.spring(duration: 0.2), value: count)
        .animation(.easeInOut(duration: 0.3), value: targetReached)
        .onChange(of: count) { _, newValue in
            if newValue >= targetReps && !targetReached {
                targetReached = true
                if autoCompleteAtTarget && repCounter == nil {
                    showingCompletion = true
                    finish(reps: newValue)
                }
            }
        }
    }

    private func tapRep() {
        manualCount += 1
    }

    private func adjustCount(by delta: Int) {
        guard let counter = repCounter else { return }
        counter.count = max(0, counter.count + delta)
    }

    private func finish(reps: Int) {
        onComplete(reps)
    }
}
