import SwiftUI

struct WatchRealTimeCountingView: View {
    let targetReps: Int
    let setNumber: Int
    let totalSets: Int
    let onComplete: (Int) -> Void

    @State private var count: Int = 0
    @State private var crownValue: Double = 0

    var body: some View {
        VStack(spacing: 4) {
            Text("Set \(setNumber) of \(totalSets)")
                .font(.caption)
                .foregroundStyle(.secondary)

            progressDots

            Spacer(minLength: 2)

            Text("\(count)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())

            Text("/ \(targetReps) target")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer(minLength: 2)

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
            if clamped != count { count = clamped }
        }
    }

    private func tapRep() {
        count += 1
        crownValue = Double(count)
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
