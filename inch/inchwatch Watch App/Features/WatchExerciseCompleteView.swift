import SwiftUI
import InchShared

struct WatchExerciseCompleteView: View {
    let exerciseName: String
    let totalReps: Int
    let remainingSessions: [WatchSession]
    let onDone: (WatchSession?) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.green)

                Text(exerciseName)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text("\(totalReps) reps")
                    .font(.title3)
                    .bold()
                    .foregroundStyle(.secondary)

                if !remainingSessions.isEmpty {
                    Divider()
                        .padding(.vertical, 4)

                    Text("Up next")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(remainingSessions) { session in
                        Button(session.exerciseName) {
                            onDone(session)
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }
                }

                Button("Done") { onDone(nil) }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, minHeight: 160)
            .padding(.vertical)
        }
        .navigationBarBackButtonHidden()
    }
}
