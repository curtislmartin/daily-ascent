# Achievements UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the flat same-icon trophy grid with category-coloured gradient badge sections that look like Apple Watch achievements.

**Architecture:** A new shared `AchievementStyle.swift` provides `BadgeDefinition`, the category→icon/colour helper, and a reusable `AchievementBadgeCircle` view. `TrophyShelfView` is fully rewritten to use these. `AchievementSheet` and `AchievementCelebrationView` are updated to swap `trophy.fill` for `AchievementBadgeCircle`.

**Tech Stack:** SwiftUI, SwiftData `@Query`, SF Symbols, `LinearGradient`

---

## File Map

| Action | Path | Responsibility |
|---|---|---|
| **Create** | `inch/inch/Components/AchievementStyle.swift` | `BadgeDefinition`, static badge list, `achievementStyle(for:)`, `AchievementBadgeCircle` |
| **Rewrite** | `inch/inch/Features/History/TrophyShelfView.swift` | Sectioned grid, dynamic per-exercise badges, detail sheet |
| **Modify** | `inch/inch/Features/Workout/AchievementSheet.swift` | Swap `trophy.fill` for `AchievementBadgeCircle` |
| **Modify** | `inch/inch/Features/Workout/AchievementCelebrationView.swift` | Swap `trophy.fill` for `AchievementBadgeCircle`, recolour fallback glow |

---

## Task 1: Create `AchievementStyle.swift`

**Files:**
- Create: `inch/inch/Components/AchievementStyle.swift`

This file is the single source of truth for category→icon/colour mapping, the `BadgeDefinition` data type, and the reusable `AchievementBadgeCircle` view used by all three callers.

- [ ] **Step 1: Create the file**

Create `inch/inch/Components/AchievementStyle.swift` with the following content:

```swift
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
```

- [ ] **Step 2: Add `AchievementStyle.swift` to the Xcode project**

Open `inch/inch.xcodeproj` in Xcode and add `AchievementStyle.swift` to the `inch` target under the `Components` group. (The file already exists on disk — use "Add Files to inch…" and select it, or drag it into the Components group in the Project Navigator.) Verify it appears under the `inch` target membership, not the watch target.

- [ ] **Step 3: Build to confirm no errors**

Build the `inch` scheme (`⌘B`). Expected: builds cleanly. The new file introduces no dependencies — it's self-contained.

- [ ] **Step 4: Commit**

```bash
git add inch/inch/Components/AchievementStyle.swift inch/inch.xcodeproj/project.pbxproj
git commit -m "feat: add AchievementStyle — BadgeDefinition, achievementStyle(for:), AchievementBadgeCircle"
```

---

## Task 2: Rewrite `TrophyShelfView.swift`

**Files:**
- Rewrite: `inch/inch/Features/History/TrophyShelfView.swift`

This is the main redesign. The file contains three types: `TrophyShelfView` (the screen), `TrophyBadge` (a grid cell), and `TrophyDetailSheet` (the tap-to-open sheet). All three are replaced.

- [ ] **Step 1: Replace the file contents**

Replace the entire content of `inch/inch/Features/History/TrophyShelfView.swift` with:

```swift
import SwiftUI
import SwiftData
import InchShared

// MARK: - TrophyShelfView

struct TrophyShelfView: View {
    @Query private var achievements: [Achievement]
    @Query private var enrolments: [ExerciseEnrolment]

    var body: some View {
        let badges = buildBadges()
        let earnedIds = Set(achievements.map(\.id))

        if badges.isEmpty {
            emptyState
                .navigationTitle("Achievements")
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(sections(from: badges, earnedIds: earnedIds), id: \.category) { section in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(section.title)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 20) {
                                ForEach(section.badges, id: \.id) { definition in
                                    TrophyBadge(
                                        definition: definition,
                                        achievement: achievements.first { $0.id == definition.id }
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

    private var emptyState: some View {
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
    }

    /// Builds the full ordered badge list: static badges + per-exercise dynamic badges.
    private func buildBadges() -> [BadgeDefinition] {
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
    ]

    private func sections(from badges: [BadgeDefinition], earnedIds: Set<String>) -> [Section] {
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
                    Text("\(value) reps")
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
                        Text("Personal best: \(value) reps")
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
```

- [ ] **Step 2: Build to confirm no errors**

Build the `inch` scheme (`⌘B`). Expected: builds cleanly. If you see "cannot find type 'Achievement'" or similar, verify `import InchShared` is present and the `InchShared` package is linked to the `inch` target.

- [ ] **Step 3: Smoke test on simulator**

Run on iPhone 16 Pro simulator. Navigate to **Me → Achievements** tab. Verify:
- Sections appear with headers ("Milestones", "Streaks", etc.)
- Locked badges show grey circles; earned ones show coloured gradient circles
- Tapping a badge opens the detail sheet with the correct icon, name, description
- "Done" button dismisses the sheet

- [ ] **Step 4: Commit**

```bash
git add inch/inch/Features/History/TrophyShelfView.swift
git commit -m "feat: rewrite TrophyShelfView with categorised gradient badge sections"
```

---

## Task 3: Update `AchievementSheet.swift`

**Files:**
- Modify: `inch/inch/Features/Workout/AchievementSheet.swift`

Swap the `trophy.fill` icon for `AchievementBadgeCircle`. This sheet appears post-workout when a new achievement is unlocked.

- [ ] **Step 1: Replace the file contents**

Replace the entire content of `inch/inch/Features/Workout/AchievementSheet.swift` with:

```swift
import SwiftUI
import InchShared

struct AchievementSheet: View {
    let achievement: Achievement
    let onDismiss: () -> Void
    @State private var badgeScale: Double = 0.1

    var body: some View {
        VStack(spacing: 24) {
            AchievementBadgeCircle(
                category: achievement.category,
                earned: true,
                diameter: 100,
                iconSize: 44
            )
            .scaleEffect(badgeScale)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    badgeScale = 1.0
                }
            }
            .sensoryFeedback(.success, trigger: true)

            VStack(spacing: 8) {
                Text("Achievement Unlocked")
                    .font(.caption).foregroundStyle(.secondary)
                Text(achievement.id.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.title2).fontWeight(.bold)
                if let date = achievement.unlockedAt as Date? {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Button("Nice!") { onDismiss() }
                .buttonStyle(.borderedProminent)
                .padding(.bottom)
        }
        .padding(.top, 32)
        .padding(.horizontal)
        .presentationDetents([.medium])
    }
}
```

- [ ] **Step 2: Build to confirm no errors**

Build the `inch` scheme (`⌘B`). Expected: builds cleanly.

- [ ] **Step 3: Smoke test on simulator**

Trigger an achievement unlock (e.g. complete a workout session that earns "First Workout" if not already earned, or use the Debug tab if present). Verify the sheet shows a coloured gradient circle instead of a yellow trophy.

- [ ] **Step 4: Commit**

```bash
git add inch/inch/Features/Workout/AchievementSheet.swift
git commit -m "feat: update AchievementSheet to use category gradient badge"
```

---

## Task 4: Update `AchievementCelebrationView.swift`

**Files:**
- Modify: `inch/inch/Features/Workout/AchievementCelebrationView.swift`

Swap the `trophy.fill` icon for `AchievementBadgeCircle` and recolour the reduced-motion fallback glow to match the category accent.

- [ ] **Step 1: Replace the file contents**

Replace the entire content of `inch/inch/Features/Workout/AchievementCelebrationView.swift` with:

```swift
import SwiftUI
import UIKit
import InchShared

struct AchievementCelebrationView: View {
    let achievement: Achievement
    let onDismiss: () -> Void
    @State private var badgeScale: Double = 0.1

    private var accentColor: Color { achievementStyle(for: achievement.category).color }

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()

            if !UIAccessibility.isReduceMotionEnabled {
                ConfettiView()
            } else {
                Circle()
                    .fill(accentColor.opacity(0.3))
                    .frame(width: 300, height: 300)
                    .blur(radius: 40)
            }

            VStack(spacing: 32) {
                Spacer()

                AchievementBadgeCircle(
                    category: achievement.category,
                    earned: true,
                    diameter: 100,
                    iconSize: 44
                )
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
```

- [ ] **Step 2: Build to confirm no errors**

Build the `inch` scheme (`⌘B`). Expected: builds cleanly.

- [ ] **Step 3: Smoke test on simulator**

Trigger the full-screen celebration view (complete a workout on a first session to earn "First Workout", or use a debug shortcut). Verify:
- The gradient circle appears instead of the yellow trophy
- The circle colour matches the achievement category (gold for milestones, orange for streaks, etc.)
- On a device or simulator with Reduce Motion enabled in Accessibility settings, the background glow matches the category colour instead of yellow

- [ ] **Step 4: Commit**

```bash
git add inch/inch/Features/Workout/AchievementCelebrationView.swift
git commit -m "feat: update AchievementCelebrationView to use category gradient badge"
```
