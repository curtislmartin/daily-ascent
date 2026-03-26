import SwiftUI
import WatchKit

struct WatchTimedSetView: View {
    let targetSeconds: Int   // 0 = test day
    let onComplete: (_ actualDuration: Double) -> Void

    @State private var elapsed: Double = 0
    @State private var isComplete: Bool = false

    private var isTestDay: Bool { targetSeconds == 0 }

    private var displaySeconds: Int {
        isTestDay ? Int(elapsed) : max(0, targetSeconds - Int(elapsed))
    }

    private var progress: Double {
        isTestDay ? 0 : (targetSeconds > 0 ? min(elapsed / Double(targetSeconds), 1) : 0)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(.secondary.opacity(0.2), lineWidth: 6)
                if !isTestDay {
                    Circle()
                        .trim(from: 0, to: 1 - progress)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }

                Text(timeText(displaySeconds))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(width: 100, height: 100)
            .animation(.linear(duration: 0.1), value: elapsed)

            Button("Stop") {
                finish()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isComplete)
        }
        .task {
            let startDate = Date.now
            while !isComplete {
                try? await Task.sleep(for: .milliseconds(100))
                elapsed = Date.now.timeIntervalSince(startDate)
                if !isTestDay && elapsed >= Double(targetSeconds) && !isComplete {
                    isComplete = true
                    WKInterfaceDevice.current().play(.success)
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
        seconds >= 60 ? "\(seconds / 60):\(String(format: "%02d", seconds % 60))" : "\(seconds)s"
    }
}
