import SwiftUI
import Charts
import InchShared

struct HistoryStatsView: View {
    let stats: HistoryViewModel.HistoryStats
    let streakState: StreakState?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                streakCard
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                completionRingCard
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                if !stats.weeklyData.isEmpty {
                    volumeChartCard
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                }

                if !stats.exerciseStats.isEmpty {
                    exerciseStatsCard
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }

    private var streakCard: some View {
        HStack(spacing: 0) {
            VStack(alignment: .center, spacing: 4) {
                Text("Current Streak")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(streakState?.currentStreak ?? 0)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                    .font(.title3)
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .center, spacing: 4) {
                Text("Best Streak")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(streakState?.longestStreak ?? 0)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                    .font(.title3)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var completionRingCard: some View {
        VStack(spacing: 8) {
            Text("This Week")
                .font(.headline)
            Chart {
                SectorMark(
                    angle: .value("Trained", stats.daysTrainedThisWeek),
                    innerRadius: .ratio(0.6)
                )
                .foregroundStyle(Color.accentColor)

                SectorMark(
                    angle: .value("Rest", max(0, 7 - stats.daysTrainedThisWeek)),
                    innerRadius: .ratio(0.6)
                )
                .foregroundStyle(Color.secondary.opacity(0.2))
            }
            .frame(height: 140)
            .overlay {
                Text("\(stats.daysTrainedThisWeek)/7")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
        }
    }

    private var volumeChartCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weekly Volume")
                .font(.headline)
            WeeklyVolumeChart(weeklyData: stats.weeklyData)
        }
    }

    private var exerciseStatsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("By Exercise")
                .font(.headline)
            VStack(spacing: 0) {
                ForEach(stats.exerciseStats) { exercise in
                    ExerciseStatRow(stat: exercise)
                    if exercise.id != stats.exerciseStats.last?.id {
                        Divider()
                            .padding(.leading, 44)
                    }
                }
            }
        }
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
