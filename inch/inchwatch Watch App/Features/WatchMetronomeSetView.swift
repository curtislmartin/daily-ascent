import SwiftUI
import WatchKit

struct WatchMetronomeSetView: View {
    let targetReps: Int
    let beatIntervalSeconds: Double
    let beatPattern: [String]       // ["strong", "regular", ...]
    let sidesPerRep: Int
    let onDone: (Int) -> Void

    @State private var repCount: Int = 0
    @State private var currentSide: Int = 1
    @State private var isStrong: Bool = false
    @State private var pulseScale: Double = 1.0
    @State private var countdownRemaining: Int = 3
    @State private var isCountingDown: Bool = true

    private var beatPatternParsed: [Bool] {
        beatPattern.map { $0 == "strong" }
    }

    var body: some View {
        VStack(spacing: 8) {
            if isCountingDown {
                countdownView
            } else {
                metronomeView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await runCountdown()
            await runMetronome()
        }
    }

    // MARK: - Subviews

    private var countdownView: some View {
        VStack(spacing: 4) {
            Text("Get Ready")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(countdownRemaining)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
                .animation(.snappy, value: countdownRemaining)
        }
    }

    private var metronomeView: some View {
        VStack(spacing: 6) {
            Text("\(repCount)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
                .animation(.snappy, value: repCount)

            Text("reps")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if sidesPerRep == 2 {
                Text(currentSide == 1 ? "Left" : "Right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .animation(.snappy, value: currentSide)
            }

            Circle()
                .fill(isStrong ? Color.accentColor : Color.accentColor.opacity(0.5))
                .frame(width: 32, height: 32)
                .scaleEffect(pulseScale)
                .animation(.easeOut(duration: beatIntervalSeconds * 0.3), value: pulseScale)

            Button("Done") {
                onDone(repCount)
            }
            .buttonStyle(.borderedProminent)
            .font(.caption)
        }
    }

    // MARK: - Async loops

    private func runCountdown() async {
        for tick in stride(from: 3, through: 1, by: -1) {
            countdownRemaining = tick
            WKInterfaceDevice.current().play(.success)
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
        }
        WKInterfaceDevice.current().play(.success)
        isCountingDown = false
    }

    private func runMetronome() async {
        let pattern = beatPatternParsed
        guard !pattern.isEmpty, beatIntervalSeconds > 0 else { return }

        let beatsPerRep = pattern.count * sidesPerRep
        var totalBeatIndex = 0

        while true {
            let positionInSide = totalBeatIndex % pattern.count
            let sideNumber = (totalBeatIndex / pattern.count) % sidesPerRep + 1
            let strong = pattern[positionInSide]

            isStrong = strong
            pulseScale = 1.4
            currentSide = sideNumber
            WKInterfaceDevice.current().play(strong ? .success : .click)

            do { try await Task.sleep(for: .seconds(beatIntervalSeconds * 0.15)) } catch { return }
            pulseScale = 1.0

            totalBeatIndex += 1
            if totalBeatIndex % beatsPerRep == 0 {
                repCount += 1
            }

            do { try await Task.sleep(for: .seconds(beatIntervalSeconds * 0.85)) } catch { return }
        }
    }
}
