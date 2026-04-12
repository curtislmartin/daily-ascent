import SwiftUI
import SwiftData
import InchShared

// MARK: - TrophyShelfView

struct TrophyShelfView: View {
    @Environment(CommunityBenchmarkService.self) private var communityBenchmark
    @Query private var achievements: [Achievement]
    @Query private var enrolments: [ExerciseEnrolment]
    @Query private var streakStates: [StreakState]
    @Query private var allSettings: [UserSettings]

    var body: some View {
        let badges = buildBadges(earnedIds: Set(achievements.map(\.id)))
        let achievementById = Dictionary(achievements.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        if enrolments.filter(\.isActive).isEmpty && achievements.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "star.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("Complete a workout to earn your first achievement.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .navigationTitle("Achievements")
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if allSettings.first?.communityBenchmarksEnabled == true,
                       communityBenchmark.distributionCache.lastFetched != nil {
                        CommunityStatsSection(
                            distributionCache: communityBenchmark.distributionCache,
                            enrolments: enrolments,
                            achievements: achievements,
                            streakState: streakStates.first
                        )
                    }

                    ForEach(Self.sections(from: badges), id: \.category) { section in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(section.title)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 20) {
                                ForEach(section.badges, id: \.id) { definition in
                                    TrophyBadge(
                                        definition: definition,
                                        achievement: achievementById[definition.id]
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Achievements")
        }
    }

    // MARK: - Private

    /// Builds the full ordered badge list: static badges + per-exercise dynamic badges.
    private func buildBadges(earnedIds: Set<String>) -> [BadgeDefinition] {
        var result = BadgeDefinition.staticBadges

        // Active enrolment ghost badges
        let activeEnrolments = enrolments.filter(\.isActive)
        let activeExerciseIds = Set(activeEnrolments.compactMap { $0.exerciseDefinition?.exerciseId })

        for enrolment in activeEnrolments {
            guard let def = enrolment.exerciseDefinition else { continue }
            let name = def.name
            let exId = def.exerciseId
            result.append(BadgeDefinition(
                id: "sessions_10_\(exId)",
                label: "\(name) × 10",
                category: "consistency",
                description: "Complete 10 sessions of this exercise"
            ))
            result.append(BadgeDefinition(
                id: "personal_best_\(exId)",
                label: "\(name) PB",
                category: "performance",
                description: "Your highest total rep count for this exercise"
            ))
        }

        // Earned badges from now-inactive enrolments (show as earned even without ghost)
        let earnedPerExercise = achievements.filter { a in
            (a.id.hasPrefix("sessions_10_") || a.id.hasPrefix("personal_best_"))
            && !(activeExerciseIds.contains(a.exerciseId ?? ""))
        }
        for achievement in earnedPerExercise {
            guard let exId = achievement.exerciseId,
                  !result.contains(where: { $0.id == achievement.id }) else { continue }
            let name = exId.replacingOccurrences(of: "_", with: " ").capitalized
            if achievement.id.hasPrefix("sessions_10_") {
                result.append(BadgeDefinition(
                    id: achievement.id,
                    label: "\(name) × 10",
                    category: "consistency",
                    description: "Complete 10 sessions of this exercise"
                ))
            } else {
                result.append(BadgeDefinition(
                    id: achievement.id,
                    label: "\(name) PB",
                    category: "performance",
                    description: "Your highest total rep count for this exercise"
                ))
            }
        }

        result = result.filter { !$0.hidden || earnedIds.contains($0.id) }
        return result
    }

    private struct Section {
        let category: String
        let title: String
        let badges: [BadgeDefinition]
    }

    private static let sectionOrder: [(category: String, title: String)] = [
        ("milestone", "Milestones"),
        ("streak", "Streaks"),
        ("consistency", "Consistency"),
        ("performance", "Performance"),
        ("journey", "Journey"),
        ("community", "Community"),
        ("time", "Time of Day"),
        ("seasonal", "Seasonal"),
        ("holiday", "Holidays"),
        ("fun", "Fun"),
    ]

    private static func sections(from badges: [BadgeDefinition]) -> [Section] {
        Self.sectionOrder.compactMap { entry in
            let matching = badges.filter { $0.category == entry.category }
            guard !matching.isEmpty else { return nil }
            return Section(category: entry.category, title: entry.title, badges: matching)
        }
    }
}

// MARK: - TrophyBadge

private struct TrophyBadge: View {
    let definition: BadgeDefinition
    let achievement: Achievement?
    @State private var showDetail = false

    private var earned: Bool { achievement != nil }

    var body: some View {
        VStack(spacing: 6) {
            AchievementBadgeCircle(
                category: definition.category,
                earned: earned,
                diameter: 56,
                iconSize: 28
            )

            Text(definition.label)
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(earned ? Color.primary : Color.secondary)

            if let a = achievement {
                if let value = a.numericValue {
                    Text("\(value.formatted()) reps")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text(a.unlockedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 80)
        .onTapGesture { showDetail = true }
        .sheet(isPresented: $showDetail) {
            TrophyDetailSheet(definition: definition, achievement: achievement)
        }
    }
}

// MARK: - TrophyDetailSheet

private struct TrophyDetailSheet: View {
    let definition: BadgeDefinition
    let achievement: Achievement?
    @Environment(\.dismiss) private var dismiss

    private var earned: Bool { achievement != nil }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                AchievementBadgeCircle(
                    category: definition.category,
                    earned: earned,
                    diameter: 100,
                    iconSize: 44
                )

                Text(definition.label)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(definition.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if let a = achievement {
                    Text(a.unlockedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let value = a.numericValue {
                        Text("Personal best: \(value.formatted()) reps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Not yet earned")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
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
