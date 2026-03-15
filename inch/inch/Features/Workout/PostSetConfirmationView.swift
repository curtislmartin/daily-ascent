import SwiftUI

struct PostSetConfirmationView: View {
    let targetReps: Int
    let duration: Double
    let onConfirm: (Int) -> Void

    @State private var actualReps: Int

    init(targetReps: Int, duration: Double, onConfirm: @escaping (Int) -> Void) {
        self.targetReps = targetReps
        self.duration = duration
        self.onConfirm = onConfirm
        _actualReps = State(initialValue: targetReps)
    }

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 8) {
                Text("Set Complete")
                    .font(.title)
                    .fontWeight(.bold)
                Text(durationText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 16) {
                Text("Reps completed")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 32) {
                    Button {
                        if actualReps > 0 { actualReps -= 1 }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)
                    }

                    Text("\(actualReps)")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .frame(minWidth: 100)

                    Button {
                        actualReps += 1
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.accentColor)
                    }
                }

                if actualReps != targetReps {
                    Text("Target was \(targetReps)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button("Confirm") {
                onConfirm(actualReps)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(actualReps == 0)
        }
        .padding()
        .navigationTitle("How many reps?")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var durationText: String {
        let seconds = Int(duration)
        if seconds < 60 {
            return "\(seconds)s"
        } else {
            return "\(seconds / 60)m \(seconds % 60)s"
        }
    }
}
