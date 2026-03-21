import SwiftUI

struct ExerciseCompleteView: View {
    let exerciseName: String
    let totalReps: Int
    let previousSessionReps: Int?
    let nextDate: Date?
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.green)

                Text("Done!")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(exerciseName)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(exerciseName) complete. \(totalReps) total reps.")

            VStack(spacing: 8) {
                if totalReps > 0 {
                    Text("\(totalReps) total reps")
                        .font(.headline)
                }
                if let prev = previousSessionReps, prev > 0 {
                    let delta = totalReps - prev
                    Text("\(delta >= 0 ? "+" : "")\(delta) vs last session")
                        .font(.subheadline)
                        .foregroundStyle(delta >= 0 ? .green : .secondary)
                }
                if let next = nextDate {
                    Text("Next session \(next.formatted(.relative(presentation: .named)))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button("Done") {
                onDone()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .navigationBarBackButtonHidden()
    }
}
