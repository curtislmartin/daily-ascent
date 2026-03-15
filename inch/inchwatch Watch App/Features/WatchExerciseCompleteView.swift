import SwiftUI

struct WatchExerciseCompleteView: View {
    let exerciseName: String
    let totalReps: Int
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.green)

            Text(exerciseName)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("\(totalReps) reps")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Button("Done") { onDone() }
                .buttonStyle(.borderedProminent)
        }
        .navigationBarBackButtonHidden()
    }
}
