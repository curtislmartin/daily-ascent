import SwiftUI
import InchShared

struct SessionSetRow: View {
    let set: CompletedSet

    var body: some View {
        HStack {
            Text("Set \(set.setNumber)")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)

            if set.isTest {
                Text("TEST")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.15), in: Capsule())
                    .foregroundStyle(.orange)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if set.countingMode == .timed, let duration = set.setDurationSeconds {
                    Text(String(format: "%.0fs hold", duration))
                        .font(.body)
                        .fontWeight(.medium)
                } else {
                    Text("\(set.actualReps) reps")
                        .font(.body)
                        .fontWeight(.medium)
                }
                if set.countingMode != .timed, set.actualReps != set.targetReps {
                    Text("target \(set.targetReps)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if set.countingMode == .timed, let targetDuration = set.targetDurationSeconds,
                          let actualDuration = set.setDurationSeconds,
                          Int(actualDuration) != targetDuration {
                    Text("target \(targetDuration)s")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
