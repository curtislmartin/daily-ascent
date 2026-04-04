# Achievements UI Redesign

**Date:** 2026-04-04
**Status:** Approved

## Problem

The current `TrophyShelfView` displays all achievements using the same `trophy.fill` / `trophy` SF Symbol regardless of category or significance. Earned and unearned badges look nearly identical (yellow vs grey), providing no meaningful visual differentiation. The experience is flat and doesn't feel rewarding.

## Goal

Redesign the achievements screen to feel like a progress tracker — celebrating what users have earned, hinting at what's ahead, without duplicating progress information already shown in the Stats tab.

## Design

### Category Mapping

The `Achievement` model's `category: String` property is the authoritative source for section assignment. The mapping is:

| `category` value | Section Label | Accent Color | SF Symbol |
|---|---|---|---|
| `"milestone"` | Milestones | `Color.yellow` | `star.fill` |
| `"streak"` | Streaks | `Color.orange` | `flame.fill` |
| `"consistency"` | Consistency | `Color.blue` | `calendar.badge.checkmark` |
| `"performance"` | Performance | `Color.teal` | `bolt.fill` |
| `"journey"` | Journey | `Color.purple` | `map.fill` |

This table is the single definition of the mapping. All badge rendering, section grouping, celebration views, and detail sheets derive icon and colour from it.

### Badge Definition Type

Replace the existing `[(id: String, label: String)]` tuple array with:

```swift
struct BadgeDefinition {
    let id: String
    let label: String
    let category: String       // matches a key in the category mapping table
    let description: String    // shown in the detail sheet
}
```

### Static Badge List

The fixed badges (not dependent on enrolment):

| `id` | `label` | `category` | `description` |
|---|---|---|---|
| `first_workout` | First Workout | `milestone` | Complete your first workout session |
| `first_test` | First Test | `milestone` | Pass your first level test |
| `program_complete` | Program Complete | `milestone` | Complete all levels across every exercise |
| `streak_3` | 3-Day Streak | `streak` | Train on 3 consecutive days |
| `streak_7` | 7-Day Streak | `streak` | Maintain a 7-day training streak |
| `streak_14` | 14-Day Streak | `streak` | Maintain a 14-day training streak |
| `streak_30` | 30-Day Streak | `streak` | Maintain a 30-day training streak |
| `streak_60` | 60-Day Streak | `streak` | Maintain a 60-day training streak |
| `streak_100` | 100-Day Streak | `streak` | Maintain a 100-day training streak |
| `sessions_5` | 5 Sessions | `consistency` | Complete 5 training sessions |
| `sessions_10` | 10 Sessions | `consistency` | Complete 10 training sessions |
| `sessions_25` | 25 Sessions | `consistency` | Complete 25 training sessions |
| `sessions_50` | 50 Sessions | `consistency` | Complete 50 training sessions |
| `sessions_100` | 100 Sessions | `consistency` | Complete 100 training sessions |
| `the_full_set` | The Full Set | `journey` | Train every enrolled exercise in one week |
| `test_gauntlet` | Test Gauntlet | `journey` | Pass level tests in 3 or more exercises |

Note: `level_complete_*` achievements are not shown as ghost badges because the set is unbounded (one per exercise per level). They are still stored and celebrated post-workout but are not listed in `TrophyShelfView`.

### Dynamic Per-Exercise Badges

`TrophyShelfView` adds `@Query private var enrolments: [ExerciseEnrolment]` alongside its existing `@Query private var achievements: [Achievement]`. `ExerciseEnrolment` has a confirmed `exerciseDefinition: ExerciseDefinition?` relationship (see `ExerciseEnrolment.swift:23`); `ExerciseDefinition` has a `name: String` property.

For each active enrolment (`isActive == true`), derive two additional `BadgeDefinition` values at render time:

```swift
let exerciseName = enrolment.exerciseDefinition?.name
    ?? enrolment.exerciseId.replacingOccurrences(of: "_", with: " ").capitalized

BadgeDefinition(
    id: "sessions_10_\(enrolment.exerciseId)",
    label: "\(exerciseName) × 10",
    category: "consistency",
    description: "Complete 10 sessions of this exercise"
)

BadgeDefinition(
    id: "personal_best_\(enrolment.exerciseId)",
    label: "\(exerciseName) PB",
    category: "performance",
    description: "Your highest total rep count for this exercise"
)
```

The `sessions_10_*` per-exercise badge and the static `sessions_10` global badge are **intentionally distinct**: one tracks overall session count across all exercises; the other tracks sessions for a specific exercise. Both appear in the Consistency section.

**Inactive enrolments:** Ghost badge entries are only generated for active enrolments (`isActive == true`). However, earned `Achievement` records for previously active (now inactive) exercises remain in the store and should still appear as earned. The view derives their `BadgeDefinition` on-the-fly from the earned record's `exerciseId`, using the same exercise name fallback.

### Category Mapping Helper

To avoid duplicating the category-to-icon/colour lookup across `TrophyShelfView`, `AchievementSheet`, and `AchievementCelebrationView`, define a file-local or internal helper — e.g. a static function or computed property on `BadgeDefinition` — that returns `(symbol: String, color: Color)` given a `category: String`. All three files import and use this single function.

### How `numericValue` is Populated

`AchievementChecker` returns a new `Achievement` value for a personal best update; the call site is responsible for mutating the existing `Achievement` record's `numericValue` in context (it does not insert a second record). There is therefore exactly one `Achievement` record per `personal_best_*` ID, and `numericValue` is always set on it. The UI simply calls `achievements.first(where: { $0.id == definition.id })` to match — no dedup needed.

### Screen Structure

`TrophyShelfView` is a `ScrollView` containing the 5 sections in the category mapping order. Each section shows:

- A section header label (`.headline`, `.secondary` colour)
- A `LazyVGrid` with `GridItem(.adaptive(minimum: 80))` columns of badges

**Section visibility:** A section is shown if and only if it has at least one `BadgeDefinition` entry (static or dynamic). Sections with zero entries are hidden entirely. The `"performance"` section appears as soon as the user has at least one active enrolment (because a ghost `personal_best_*` badge exists for each active enrolment).

**Full-screen empty state:** If the combined static + dynamic badge list is empty (no enrolments and no earned achievements — only possible before onboarding is complete), show a centred placeholder: `star.fill` in `.secondary` at `.system(size: 40)` with the text "Complete a workout to earn your first achievement." in `.subheadline`, `.secondary`. In practice the static badge list is never empty (milestone/streak/consistency/journey badges are always present), so this state is a safety net.

### Badge Design

**Sizes:**

| Context | Tile width | Circle diameter | Icon font size |
|---|---|---|---|
| Grid | 80pt | 56pt | `.system(size: 28)` |
| Detail sheet | n/a | 100pt | `.system(size: 44)` |

**Earned state:**
- `Circle` with a `LinearGradient` from `accentColor.opacity(0.6)` (startPoint: `.top`) to `accentColor` (endPoint: `.bottom`), where `accentColor` is the section accent colour
- SF Symbol at the appropriate size in `.foregroundStyle(.white)` inside the circle
- Achievement name below in `.caption2`, `.primary`
- Second line in `.caption2`, `.secondary`:
  - If `achievement.numericValue != nil` (performance/personal best only): `"\(value) reps"`
  - Otherwise: `date.formatted(date: .abbreviated, time: .omitted)` (e.g. "Apr 4, 2026")

**Locked state:**
- `Circle` filled with `Color(.systemFill)`
- SF Symbol at the appropriate size in `.foregroundStyle(.secondary)` inside the circle
- Achievement name below in `.caption2`, `.secondary`
- No second line

### Detail Sheet

Tapping any badge opens a sheet with `presentationDetents([.medium])`. The sheet is draggable to dismiss and has a "Done" `ToolbarItem(placement: .confirmationAction)` button.

Contents (vertically stacked, centred):

1. Large badge (100pt circle, detail icon size, same earned/locked rendering rules as grid)
2. Achievement name in `.title2`, `.fontWeight(.bold)`
3. `definition.description` in `.body`, `.secondary`
4. If earned:
   - Date line: `date.formatted(date: .abbreviated, time: .omitted)` in `.caption`, `.secondary`
   - If `numericValue` is present: "Personal best: \(value) reps" in `.caption`, `.secondary`
5. If locked: "Not yet earned" in `.caption`, `.secondary`

### Celebration Views

**`AchievementCelebrationView`** and **`AchievementSheet`** both replace `Image(systemName: "trophy.fill")` with a gradient circle badge. Derive the icon and accent colour from the category mapping table using `achievement.category`. Use the detail-sheet size (100pt circle, `.system(size: 44)` icon).

`AchievementCelebrationView` has a reduced-motion fallback branch (`UIAccessibility.isReduceMotionEnabled`). The `Circle().fill(.yellow.opacity(0.3))` glow should be recoloured to `accentColor.opacity(0.3)` using the category accent colour.

`AchievementSheet` has no reduced-motion branch — no changes needed there beyond replacing the icon.

## Files Affected

- `inch/inch/Features/History/TrophyShelfView.swift` — full redesign
- `inch/inch/Features/Workout/AchievementSheet.swift` — replace trophy icon with category badge
- `inch/inch/Features/Workout/AchievementCelebrationView.swift` — replace trophy icon with category badge

## Out of Scope

- Custom per-achievement artwork (deferred to v2)
- Progress ladders toward next tier (duplicates Stats tab)
- Social sharing changes
