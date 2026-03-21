import SwiftUI

struct RealTimeCountingView: View {
    let targetReps: Int
    let onComplete: (Int) -> Void

    @State private var count: Int = 0
    @State private var showingCompletion: Bool = false

    private var progress: Double {
        targetReps > 0 ? min(Double(count) / Double(targetReps), 1) : 0
    }

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(.secondary.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 0.2), value: count)

                Text("\(count)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .frame(width: 200, height: 200)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(count) reps")

            Text("target: \(targetReps)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

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
        .animation(.spring(duration: 0.2), value: count)
    }

    private func tapRep() {
        count += 1
        if count >= targetReps {
            showingCompletion = true
            finish(reps: count)
        }
    }

    private func finish(reps: Int) {
        onComplete(reps)
    }
}
