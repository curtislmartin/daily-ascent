import SwiftUI
import SwiftData
import InchShared

struct CommunityStatsSection: View {
    let distributionCache: CommunityDistributionCache
    let enrolments: [ExerciseEnrolment]
    let achievements: [Achievement]
    let streakState: StreakState?

    var body: some View {
        let cards = exerciseCards
        let streakPct = streakPercentile

        if !cards.isEmpty || streakPct != nil {
            VStack(alignment: .leading, spacing: 12) {
                Text("Community")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                if let streakPct {
                    streakCard(percentile: streakPct)
                        .padding(.horizontal)
                }

                if !cards.isEmpty {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(cards) { card in
                            exercisePercentileCard(card)
                        }
                    }
                    .padding(.horizontal)
                }

                Text("Based on anonymous community data")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Streak Card

    private func streakCard(percentile: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Streak Ranking")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Better than \(percentile)% of users")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            percentileBadge(percentile)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Exercise Percentile Cards

    private func exercisePercentileCard(_ card: ExerciseCard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: card.color) ?? .accentColor)
                    .frame(width: 8, height: 8)
                Text(card.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(card.bestReps) reps")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("L\(card.level) best")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                percentileBadge(card.percentile)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Percentile Badge

    private func percentileBadge(_ percentile: Int) -> some View {
        Text("Top \(100 - percentile)%")
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(percentileColor(percentile).opacity(0.15), in: Capsule())
            .foregroundStyle(percentileColor(percentile))
    }

    private func percentileColor(_ percentile: Int) -> Color {
        switch percentile {
        case 90...: return .orange
        case 75...: return .green
        case 50...: return .blue
        default:    return .secondary
        }
    }

    // MARK: - Data Computation

    private struct ExerciseCard: Identifiable {
        let id: String
        let name: String
        let color: String
        let level: Int
        let bestReps: Int
        let percentile: Int
    }

    private var exerciseCards: [ExerciseCard] {
        let pbAchievements = Dictionary(
            achievements
                .filter { $0.id.hasPrefix("personal_best_") && $0.numericValue != nil }
                .map { ($0.exerciseId ?? String($0.id.dropFirst("personal_best_".count)), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        return enrolments
            .filter(\.isActive)
            .compactMap { enrolment -> ExerciseCard? in
                guard let def = enrolment.exerciseDefinition else { return nil }
                let exId = def.exerciseId
                let level = enrolment.currentLevel

                guard let pb = pbAchievements[exId],
                      let bestReps = pb.numericValue else { return nil }

                let key = CommunityDistributionCache.cacheKey(
                    exerciseId: exId, level: level, metricType: "best_set_reps"
                )
                guard let dist = distributionCache.exercises[key],
                      dist.totalUsers >= 20 else { return nil }

                let percentile = dist.percentile(for: bestReps)

                return ExerciseCard(
                    id: exId,
                    name: def.name,
                    color: def.color,
                    level: level,
                    bestReps: bestReps,
                    percentile: percentile
                )
            }
            .sorted { $0.percentile > $1.percentile }
    }

    private var streakPercentile: Int? {
        guard let streak = streakState,
              let dist = distributionCache.streak,
              dist.totalUsers >= 20 else { return nil }
        return dist.percentile(for: streak.currentStreak)
    }
}
