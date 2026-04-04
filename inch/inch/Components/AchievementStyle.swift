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
    default:             return ("trophy.fill",                .yellow)
    }
}

// MARK: - BadgeDefinition

struct BadgeDefinition {
    let id: String
    let label: String
    let category: String     // must match a key handled by achievementStyle(for:)
    let description: String  // shown in the detail sheet

    /// All static (non-enrolment-dependent) badge definitions in display order.
    static let staticBadges: [BadgeDefinition] = [
        // Milestones
        BadgeDefinition(id: "first_workout",    label: "First Workout",    category: "milestone",    description: "Complete your first workout session"),
        BadgeDefinition(id: "first_test",       label: "First Test",       category: "milestone",    description: "Pass your first level test"),
        BadgeDefinition(id: "program_complete", label: "Program Complete", category: "milestone",    description: "Complete all levels across every exercise"),
        // Streaks
        BadgeDefinition(id: "streak_3",   label: "3-Day Streak",   category: "streak", description: "Train on 3 consecutive days"),
        BadgeDefinition(id: "streak_7",   label: "7-Day Streak",   category: "streak", description: "Maintain a 7-day training streak"),
        BadgeDefinition(id: "streak_14",  label: "14-Day Streak",  category: "streak", description: "Maintain a 14-day training streak"),
        BadgeDefinition(id: "streak_30",  label: "30-Day Streak",  category: "streak", description: "Maintain a 30-day training streak"),
        BadgeDefinition(id: "streak_60",  label: "60-Day Streak",  category: "streak", description: "Maintain a 60-day training streak"),
        BadgeDefinition(id: "streak_100", label: "100-Day Streak", category: "streak", description: "Maintain a 100-day training streak"),
        // Consistency
        BadgeDefinition(id: "sessions_5",   label: "5 Sessions",   category: "consistency", description: "Complete 5 training sessions"),
        BadgeDefinition(id: "sessions_10",  label: "10 Sessions",  category: "consistency", description: "Complete 10 training sessions"),
        BadgeDefinition(id: "sessions_25",  label: "25 Sessions",  category: "consistency", description: "Complete 25 training sessions"),
        BadgeDefinition(id: "sessions_50",  label: "50 Sessions",  category: "consistency", description: "Complete 50 training sessions"),
        BadgeDefinition(id: "sessions_100", label: "100 Sessions", category: "consistency", description: "Complete 100 training sessions"),
        // Journey
        BadgeDefinition(id: "the_full_set",  label: "The Full Set",  category: "journey", description: "Train every enrolled exercise in one week"),
        BadgeDefinition(id: "test_gauntlet", label: "Test Gauntlet", category: "journey", description: "Pass level tests in 3 or more exercises"),
    ]
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
