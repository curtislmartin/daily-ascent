import SwiftUI
import InchShared

struct SetRow: View {
    let set: CompletedSet
    let isTimed: Bool

    var body: some View {
        HStack {
            Text("Set \(set.setNumber)")
                .foregroundStyle(.primary)
            Spacer()
            if isTimed {
                if let held = set.setDurationSeconds {
                    Text(String(format: "%.0fs hold", held))
                }
                if let target = set.targetDurationSeconds {
                    Text("target \(target)s")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            } else {
                Text("\(set.actualReps) reps")
                if set.targetReps > 0 {
                    Text("target \(set.targetReps)")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
        }
    }
}
