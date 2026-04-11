import SwiftUI

// MARK: - Category mapping

/// Returns the SF Symbol name and accent colour for a given achievement category string.
/// This is the single canonical mapping used by TrophyShelfView, AchievementSheet,
/// and AchievementCelebrationView.
func achievementStyle(for category: String) -> (symbol: String, color: Color) {
    switch category {
    case "milestone":    return ("star.fill",                  .yellow)
    case "streak":       return ("flame.fill",                 .orange)
    case "consistency":  return ("calendar.badge.checkmark",   .blue)
    case "performance":  return ("bolt.fill",                  .teal)
    case "journey":      return ("map.fill",                   .purple)
    case "community":    return ("person.3.fill",              .green)
    case "time":         return ("clock.fill",                 .indigo)
    case "seasonal":     return ("leaf.fill",                  .mint)
    case "holiday":      return ("gift.fill",                  .red)
    case "fun":          return ("party.popper.fill",          .pink)
    default:             return ("trophy.fill",                .yellow)
    }
}

// MARK: - AchievementBadgeCircle

/// Reusable earned/locked badge circle. Earned: coloured gradient + white icon.
/// Locked: grey fill + secondary icon.
struct AchievementBadgeCircle: View {
    let category: String
    let earned: Bool
    let diameter: Double
    let iconSize: Double

    var body: some View {
        let style = achievementStyle(for: category)
        ZStack {
            if earned {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [style.color.opacity(0.6), style.color],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            } else {
                Circle()
                    .fill(Color(.systemFill))
            }
            Image(systemName: style.symbol)
                .font(.system(size: iconSize))
                .foregroundStyle(earned ? .white : Color.secondary)
        }
        .frame(width: diameter, height: diameter)
    }
}
