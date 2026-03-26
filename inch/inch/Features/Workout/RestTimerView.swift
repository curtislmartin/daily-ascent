import SwiftUI

struct RestTimerView: View {
    let totalSeconds: Int
    let nextSetReps: Int?
    var nextSetDuration: Int? = nil
    let onComplete: () -> Void

    @State private var remaining: Int

    init(totalSeconds: Int, nextSetReps: Int? = nil, nextSetDuration: Int? = nil, onComplete: @escaping () -> Void) {
        self.totalSeconds = totalSeconds
        self.nextSetReps = nextSetReps
        self.nextSetDuration = nextSetDuration
        self.onComplete = onComplete
        _remaining = State(initialValue: totalSeconds)
    }

    private var progress: Double {
        totalSeconds > 0 ? Double(remaining) / Double(totalSeconds) : 0
    }

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            Text("Rest")
                .font(.title2)
                .foregroundStyle(.secondary)

            ZStack {
                Circle()
                    .stroke(.secondary.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: remaining)

                Text(timeText)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(width: 200, height: 200)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Rest timer, \(remaining) second\(remaining == 1 ? "" : "s") remaining")

            if let nextSetDuration {
                Text("Next: \(nextSetDuration)s hold")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if let nextSetReps {
                Text("Next: \(nextSetReps) reps")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Skip Rest") {
                onComplete()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding()
        .navigationTitle("Rest")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            while remaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                remaining -= 1
            }
            onComplete()
        }
    }

    private var timeText: String {
        if remaining >= 60 {
            return "\(remaining / 60):\(String(format: "%02d", remaining % 60))"
        } else {
            return "\(remaining)s"
        }
    }
}
