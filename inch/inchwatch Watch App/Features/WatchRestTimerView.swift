import SwiftUI
import WatchKit

struct WatchRestTimerView: View {
    let restSeconds: Int
    let onSkip: () -> Void

    @Environment(WatchSettings.self) private var settings

    @State private var remaining: Int
    @State private var tenSecondHapticFired = false

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
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return  // Cancelled (user tapped Skip) — exit without calling onSkip again
                }
                remaining -= 1
                if remaining == 10 && !tenSecondHapticFired {
                    tenSecondHapticFired = true
                    WKInterfaceDevice.current().play(.notification)
                }
                if settings.hapticFinalCountdown && (remaining == 3 || remaining == 2 || remaining == 1) {
                    WKInterfaceDevice.current().play(.click)
                }
            }
            // Triple haptic at rest end
            WKInterfaceDevice.current().play(.success)
            do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
            WKInterfaceDevice.current().play(.success)
            do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
            WKInterfaceDevice.current().play(.success)
            onSkip()
        }
    }
}
