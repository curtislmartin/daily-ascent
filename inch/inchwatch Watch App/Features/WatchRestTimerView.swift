import SwiftUI

struct WatchRestTimerView: View {
    let restSeconds: Int
    let onSkip: () -> Void

    @State private var remaining: Int

    init(restSeconds: Int, onSkip: @escaping () -> Void) {
        self.restSeconds = restSeconds
        self.onSkip = onSkip
        _remaining = State(initialValue: restSeconds)
    }

    private var progress: Double {
        guard restSeconds > 0 else { return 1 }
        return Double(restSeconds - remaining) / Double(restSeconds)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                Text("\(remaining)")
                    .font(.system(size: 36, weight: .semibold, design: .monospaced))
            }
            .frame(width: 80, height: 80)

            Text("Rest")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Skip") { onSkip() }
                .buttonStyle(.bordered)
                .font(.caption)
        }
        .navigationTitle("Rest")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            while remaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                remaining -= 1
            }
            onSkip()
        }
    }
}
