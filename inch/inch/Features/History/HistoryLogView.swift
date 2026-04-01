import SwiftUI
import SwiftData
import InchShared

struct HistoryLogView: View {
    let weekGroups: [HistoryViewModel.WeekGroup]

    @Query private var allAchievements: [Achievement]

    var body: some View {
        if weekGroups.isEmpty {
            emptyState
        } else {
            List {
                ForEach(weekGroups) { week in
                    Section {
                        ForEach(week.days) { day in
                            DayGroupRow(
                                day: day,
                                hasAchievement: allAchievements.contains { achievement in
                                    guard let aDate = achievement.sessionDate else { return false }
                                    return Calendar.current.isDate(aDate, inSameDayAs: day.id)
                                }
                            )
                        }
                    } header: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(week.weekLabel)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("\(week.totalReps) reps · \(week.sessionCount) sessions")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No workouts yet",
            systemImage: "clock.arrow.circlepath",
            description: Text("Head to the Today tab to start training.")
        )
    }
}
