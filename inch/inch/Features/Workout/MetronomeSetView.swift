import SwiftUI

struct MetronomeSetView: View {
    let targetReps: Int
    let beatIntervalSeconds: Double
    let beatPattern: [String]       // ["strong", "regular", ...]
    let sidesPerRep: Int
    let onDone: (Int) -> Void       // called with auto-counted rep count

    @State private var repCount: Int = 0
    @State private var currentSide: Int = 1         // 1 or 2
    @State private var beatIndexInPattern: Int = 0
    @State private var isStrong: Bool = false
    @State private var pulseScale: Double = 1.0
    @State private var strongBeatFired: Int = 0
    @State private var regularBeatFired: Int = 0
    @State private var countdownRemaining: Int = 3
    @State private var isCountingDown: Bool = true

    private var beatPatternParsed: [Bool] {
        beatPattern.map { $0 == "strong" }
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            if isCountingDown {
                countdownView
            } else {
                metronomeView
            }

            Spacer()

            if !isCountingDown {
                Button("Done") {
                    onDone(repCount)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding()
        .sensoryFeedback(.impact(weight: .heavy), trigger: strongBeatFired)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: regularBeatFired)
        .task {
            await runCountdown()
            await runMetronome()
        }
    }

    // MARK: - Subviews

    private var countdownView: some View {
        VStack(spacing: 16) {
            Text("Get Ready")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("\(countdownRemaining)")
                .font(.system(size: 96, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
                .animation(.snappy, value: countdownRemaining)
        }
    }

    private var metronomeView: some View {
        VStack(spacing: 24) {
            // Rep counter
            VStack(spacing: 4) {
                Text("\(repCount)")
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                    .animation(.snappy, value: repCount)
                Text("reps")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Side indicator for bilateral exercises
            if sidesPerRep == 2 {
                Text(currentSide == 1 ? "Left" : "Right")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .animation(.snappy, value: currentSide)
            }

            // Pulsing beat indicator
            Circle()
                .fill(isStrong ? Color.accentColor : Color.accentColor.opacity(0.5))
                .frame(width: 80, height: 80)
                .scaleEffect(pulseScale)
                .animation(.easeOut(duration: beatIntervalSeconds * 0.3), value: pulseScale)

            Text("Target: \(targetReps) reps")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Async loops

    private func runCountdown() async {
        for tick in stride(from: 3, through: 1, by: -1) {
            countdownRemaining = tick
            WorkoutSounds.playCountdownTick()
            strongBeatFired += 1
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
        }
        WorkoutSounds.playGo()
        strongBeatFired += 1
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
            pulseScale = 1.3
            currentSide = sideNumber
            WorkoutSounds.playMetronomeBeat()
            if strong {
                strongBeatFired += 1
            } else {
                regularBeatFired += 1
            }

            // Reset pulse after a short flash
            do { try await Task.sleep(for: .seconds(beatIntervalSeconds * 0.15)) } catch { return }
            pulseScale = 1.0

            // Advance beat index and credit the rep immediately so tapping Done
            // at the end of the last beat counts it correctly.
            totalBeatIndex += 1
            if totalBeatIndex % beatsPerRep == 0 {
                repCount += 1
            }

            do { try await Task.sleep(for: .seconds(beatIntervalSeconds * 0.85)) } catch { return }
        }
    }
}
