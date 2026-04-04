import SwiftUI

struct ExerciseInfoSheet: View {
    let exerciseId: String
    let exerciseName: String
    let level: Int

    private var info: ExerciseInfo? {
        ExerciseContent.info(exerciseId: exerciseId, level: level)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // YouTube demo video
                YouTubePlayerView(videoId: info?.youtubeVideoId ?? "")
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                if let info {
                    // Muscle tags
                    HStack {
                        ForEach(info.muscles, id: \.self) { muscle in
                            Text(muscle)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.secondary.opacity(0.15), in: Capsule())
                        }
                    }

                    // How to do it
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How to do it")
                            .font(.headline)
                        VStack(alignment: .leading, spacing: 6) {
                            bulletRow(info.setup)
                            bulletRow(info.movement)
                            bulletRow(info.focus)
                        }
                    }

                    // Common mistake
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Common mistake")
                            .font(.headline)
                        bulletRow(info.commonMistake)
                    }

                    // Level tip
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Level \(level) tip")
                            .font(.headline)
                        Text(info.levelTip)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Content not available.")
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 24)
            }
            .padding()
        }
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func bulletRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
        }
    }
}
