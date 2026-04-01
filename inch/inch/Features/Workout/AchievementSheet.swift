import SwiftUI
import InchShared

struct AchievementSheet: View {
    let achievement: Achievement
    let onDismiss: () -> Void
    @State private var badgeScale: Double = 0.1

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 64))
                .foregroundStyle(.yellow)
                .scaleEffect(badgeScale)
                .onAppear {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                        badgeScale = 1.0
                    }
                }
                .sensoryFeedback(.success, trigger: true)

            VStack(spacing: 8) {
                Text("Achievement Unlocked")
                    .font(.caption).foregroundStyle(.secondary)
                Text(achievement.id.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.title2).fontWeight(.bold)
                if let date = achievement.unlockedAt as Date? {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Button("Nice!") { onDismiss() }
                .buttonStyle(.borderedProminent)
                .padding(.bottom)
        }
        .padding(.top, 32)
        .padding(.horizontal)
        .presentationDetents([.medium])
    }
}
