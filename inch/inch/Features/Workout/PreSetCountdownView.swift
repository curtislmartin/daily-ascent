import SwiftUI

struct PreSetCountdownView: View {
    let countdownSeconds: Int
    let holdDurationSeconds: Int  // 0 = test day (unlimited)
    let onStart: () -> Void

    @State private var remaining: Int

    init(countdownSeconds: Int, holdDurationSeconds: Int, onStart: @escaping () -> Void) {
        self.countdownSeconds = countdownSeconds
        self.holdDurationSeconds = holdDurationSeconds
        self.onStart = onStart
        _remaining = State(initialValue: countdownSeconds)
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("Get ready")
                .font(.title2)
                .foregroundStyle(.secondary)

            if holdDurationSeconds > 0 {
                Text("Hold for \(holdDurationSeconds)s")
                    .font(.headline)
            } else {
                Text("Hold as long as you can")
                    .font(.headline)
            }

            ZStack {
                Circle()
                    .stroke(.secondary.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: countdownSeconds > 0 ? Double(remaining) / Double(countdownSeconds) : 0)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: remaining)

                Text(remaining > 0 ? "\(remaining)" : "Go!")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .frame(width: 200, height: 200)

            Spacer()
        }
        .padding()
        .task {
            let endDate = Date.now.addingTimeInterval(Double(countdownSeconds))
            while remaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                remaining = max(0, Int(endDate.timeIntervalSinceNow.rounded(.up)))
            }
            onStart()
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: remaining) { _, new in
            new > 0 && new <= 3
        }
        .sensoryFeedback(.success, trigger: remaining) { _, new in
            new == 0
        }
    }
}
