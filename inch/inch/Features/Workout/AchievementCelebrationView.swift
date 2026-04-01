import SwiftUI
import UIKit
import InchShared

struct AchievementCelebrationView: View {
    let achievement: Achievement
    let onDismiss: () -> Void
    @State private var badgeScale: Double = 0.1

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()

            if !UIAccessibility.isReduceMotionEnabled {
                ConfettiView()
            } else {
                Circle()
                    .fill(.yellow.opacity(0.3))
                    .frame(width: 300, height: 300)
                    .blur(radius: 40)
            }

            VStack(spacing: 32) {
                Spacer()
                Image(systemName: "trophy.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.yellow)
                    .scaleEffect(badgeScale)
                    .onAppear {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                            badgeScale = 1.0
                        }
                    }
                    .sensoryFeedback(.impact(weight: .heavy), trigger: true)

                VStack(spacing: 8) {
                    Text("Achievement Unlocked")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(achievement.id.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.title2).fontWeight(.bold).foregroundStyle(.white)
                }

                Spacer()

                VStack(spacing: 12) {
                    ShareLink(
                        item: shareText,
                        subject: Text("Daily Ascent Achievement"),
                        message: Text(shareText)
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Continue") { onDismiss() }
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
    }

    private var shareText: String {
        "I just unlocked \"\(achievement.id.replacingOccurrences(of: "_", with: " ").capitalized)\" on Daily Ascent! 💪"
    }
}
