import SwiftUI

struct WatchPostSetView: View {
    let targetReps: Int
    let onConfirm: (Int) -> Void

    @State private var actualReps: Int

    init(targetReps: Int, onConfirm: @escaping (Int) -> Void) {
        self.targetReps = targetReps
        self.onConfirm = onConfirm
        _actualReps = State(initialValue: targetReps)
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("Reps completed")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("\(actualReps)")
                .font(.system(size: 48, weight: .bold, design: .rounded))

            HStack(spacing: 16) {
                Button {
                    if actualReps > 0 { actualReps -= 1 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Button {
                    actualReps += 1
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }

            Button("Confirm") { onConfirm(actualReps) }
                .buttonStyle(.borderedProminent)
        }
        .navigationTitle("Set Done")
        .navigationBarTitleDisplayMode(.inline)
    }
}
