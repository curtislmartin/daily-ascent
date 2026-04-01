import SwiftUI
import SwiftData
import InchShared

struct TrophyShelfView: View {
    @Query private var achievements: [Achievement]

    private let allIds: [(id: String, label: String)] = [
        ("first_workout", "First Workout"),
        ("first_test", "First Test"),
        ("streak_3", "3-Day Streak"),
        ("streak_7", "7-Day Streak"),
        ("streak_14", "14-Day Streak"),
        ("streak_30", "30-Day Streak"),
        ("streak_60", "60-Day Streak"),
        ("streak_100", "100-Day Streak"),
        ("sessions_5", "5 Sessions"),
        ("sessions_10", "10 Sessions"),
        ("sessions_25", "25 Sessions"),
        ("sessions_50", "50 Sessions"),
        ("sessions_100", "100 Sessions"),
        ("the_full_set", "The Full Set"),
        ("test_gauntlet", "Test Gauntlet"),
        ("program_complete", "Program Complete"),
    ]

    var body: some View {
        let earnedIds = Set(achievements.map(\.id))
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 20) {
                ForEach(allIds, id: \.id) { item in
                    TrophyBadge(
                        label: item.label,
                        earned: earnedIds.contains(item.id),
                        achievement: achievements.first { $0.id == item.id }
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Achievements")
    }
}

struct TrophyBadge: View {
    let label: String
    let earned: Bool
    let achievement: Achievement?
    @State private var showDetail = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: earned ? "trophy.fill" : "trophy")
                .font(.system(size: 32))
                .foregroundStyle(earned ? .yellow : Color.secondary.opacity(0.4))
            Text(label)
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(earned ? Color.primary : Color.secondary.opacity(0.5))
            if let value = achievement?.numericValue, earned {
                Text("\(value)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 80)
        .onTapGesture { showDetail = true }
        .sheet(isPresented: $showDetail) {
            TrophyDetailSheet(label: label, earned: earned, achievement: achievement)
        }
    }
}

struct TrophyDetailSheet: View {
    let label: String
    let earned: Bool
    let achievement: Achievement?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: earned ? "trophy.fill" : "trophy")
                    .font(.system(size: 60))
                    .foregroundStyle(earned ? .yellow : .secondary)
                Text(label).font(.title2).fontWeight(.bold)
                if earned, let date = achievement?.unlockedAt {
                    Text("Earned \(date.formatted(date: .abbreviated, time: .omitted))")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not yet earned").foregroundStyle(.secondary)
                }
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
