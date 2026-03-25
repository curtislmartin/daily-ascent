import SwiftUI
import InchShared

struct WatchRealTimeCountingView: View {
    let targetReps: Int
    let setNumber: Int
    let totalSets: Int
    var repCounter: RepCounter? = nil
    let onComplete: (Int) -> Void

    @State private var manualCount: Int = 0
    @State private var crownValue: Double = 0

    private var count: Int {
        repCounter?.count ?? manualCount
    }

    var body: some View {
        VStack(spacing: 4) {
            Text("Set \(setNumber) of \(totalSets)")
                .font(.caption)
                .foregroundStyle(.secondary)

            progressDots

            Spacer(minLength: 2)

            VStack(spacing: 1) {
                Text("\(count)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                if repCounter != nil {
                    Text("auto")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Text("/ \(targetReps) target")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer(minLength: 2)

            if repCounter != nil {
                Button("Done (\(count))") {
                    onComplete(count)
                }
                .buttonStyle(.borderedProminent)
                .disabled(count == 0)
            } else {
                Button {
                    tapRep()
                } label: {
                    Text("Tap to Count")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                if count > 0 {
                    Button("Done (\(count))") {
                        onComplete(count)
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: count)
        .focusable()
        .digitalCrownRotation(
            $crownValue,
            from: 0,
            through: 9999,
            by: 1,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownValue) { _, newValue in
            let clamped = max(0, Int(newValue.rounded()))
            if let counter = repCounter {
                if clamped != counter.count { counter.count = clamped }
            } else {
                if clamped != manualCount { manualCount = clamped }
            }
        }
        .onChange(of: count) { _, newValue in
            // Keep crown value in sync when auto count changes
            if abs(crownValue - Double(newValue)) > 0.5 {
                crownValue = Double(newValue)
            }
        }
    }

    private func tapRep() {
        manualCount += 1
        crownValue = Double(manualCount)
    }

    private var progressDots: some View {
        HStack(spacing: 4) {
            ForEach(0..<totalSets, id: \.self) { i in
                Circle()
                    .fill(i < setNumber - 1 ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
    }
}
