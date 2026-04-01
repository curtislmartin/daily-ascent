import SwiftUI
import InchShared

struct AchievementBanner: View {
    let achievement: Achievement
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "star.fill")
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline).fontWeight(.semibold)
                Text(achievement.id.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .sensoryFeedback(.success, trigger: true)
        .task {
            try? await Task.sleep(for: .seconds(4))
            onDismiss()
        }
        .onTapGesture { onDismiss() }
    }

    private var title: String {
        switch achievement.category {
        case "streak": return "Streak milestone!"
        case "consistency": return "Session milestone!"
        case "performance": return "Personal best!"
        default: return "Achievement unlocked!"
        }
    }
}
