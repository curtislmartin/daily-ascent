import SwiftUI
import InchShared

struct HistoryStatsView: View {
    let stats: HistoryViewModel.HistoryStats
    let streakState: StreakState?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                summaryCards
                    .padding(.horizontal)

                if !stats.weeklyData.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weekly Volume")
                            .font(.headline)
                            .padding(.horizontal)
                        WeeklyVolumeChart(weeklyData: stats.weeklyData)
                            .padding(.horizontal)
                    }
                }

                if !stats.exerciseStats.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("By Exercise")
                            .font(.headline)
                            .padding(.horizontal)
                        exerciseList
                    }
                }
            }
            .padding(.vertical)
        }
    }

    private var summaryCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(label: "Total Reps", value: stats.totalReps.formatted(), subtitle: "All time")
            StatCard(label: "Sessions", value: "\(stats.sessionCount)", subtitle: "Training days")
            if let streak = streakState {
                StatCard(label: "Streak", value: "\(streak.currentStreak)", subtitle: "Current")
                StatCard(label: "Best Streak", value: "\(streak.longestStreak)", subtitle: "Personal best")
            }
        }
    }

    private var exerciseList: some View {
        VStack(spacing: 0) {
            ForEach(stats.exerciseStats) { exercise in
                ExerciseStatRow(stat: exercise)
                if exercise.id != stats.exerciseStats.last?.id {
                    Divider()
                        .padding(.leading, 44)
                }
            }
        }
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

private struct StatCard: View {
    let label: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct ExerciseStatRow: View {
    let stat: HistoryViewModel.ExerciseStat
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: stat.color) ?? .accentColor)
                .frame(width: 10, height: 10)
                .padding(.leading, 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(stat.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("L\(stat.currentLevel) · Day \(stat.currentDay) of \(stat.totalDaysInLevel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(stat.totalReps.formatted()) reps")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.trailing, 12)
        }
        .padding(.vertical, 10)
    }
}
