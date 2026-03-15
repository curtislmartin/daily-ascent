import SwiftUI

struct RealTimeCountingView: View {
    let targetReps: Int
    let onComplete: (Int) -> Void

    @State private var count: Int = 0
    @State private var showingCompletion: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            Text("\(count) / \(targetReps)")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())

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
