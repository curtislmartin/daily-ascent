import SwiftUI

struct TimedSetView: View {
    let targetSeconds: Int   // 0 = test day (count up)
    let onComplete: (_ actualDuration: Double) -> Void

    @State private var elapsed: Double = 0
    @State private var isComplete: Bool = false

    private var isTestDay: Bool { targetSeconds == 0 }

    private var progress: Double {
        isTestDay ? 0 : (targetSeconds > 0 ? min(elapsed / Double(targetSeconds), 1) : 0)
    }

    private var displaySeconds: Int {
        isTestDay ? Int(elapsed) : max(0, targetSeconds - Int(elapsed))
    }

    private var ringColor: Color {
        isComplete ? .green : .accentColor
    }

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(.secondary.opacity(0.2), lineWidth: 8)
                if isTestDay {
                    Circle()
                        .trim(from: 0, to: min(elapsed / 120.0, 1))
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                } else {
                    Circle()
                        .trim(from: 0, to: 1 - progress)
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }

                VStack(spacing: 2) {
                    Text(timeText(displaySeconds))
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(isTestDay ? "elapsed" : "remaining")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 200, height: 200)
            .animation(.linear(duration: 0.1), value: elapsed)

            if isComplete && !isTestDay {
                Text("Hold complete!")
                    .font(.subheadline)
                    .foregroundStyle(.green)
                    .transition(.opacity.combined(with: .scale))
            } else if isTestDay {
                Text("Hold as long as you can")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("target: \(targetSeconds)s")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button("Stop") {
                finish()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isComplete)
        }
        .animation(.easeInOut(duration: 0.3), value: isComplete)
        .task {
            let startDate = Date.now
            while !isComplete {
                try? await Task.sleep(for: .milliseconds(100))
                elapsed = Date.now.timeIntervalSince(startDate)
                if !isTestDay && elapsed >= Double(targetSeconds) && !isComplete {
                    isComplete = true
                    try? await Task.sleep(for: .seconds(0.8))
                    finish()
                }
            }
        }
    }

    private func finish() {
        isComplete = true
        onComplete(elapsed)
    }

    private func timeText(_ seconds: Int) -> String {
        if seconds >= 60 {
            return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
        } else {
            return "\(seconds)s"
        }
    }
}
