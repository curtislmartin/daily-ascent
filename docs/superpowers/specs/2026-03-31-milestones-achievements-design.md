# Milestones & Achievements — Design Spec

**Date:** 2026-03-31
**Status:** Draft
**App:** Daily Ascent (iOS + watchOS bodyweight training)

---

## Problem

The app has streaks and level-up celebrations but no broader recognition system. An 18-week program is a long commitment. Users who complete Level 1 Push-Ups have done something genuinely meaningful — but the app doesn't mark it. The mid-program "motivation valley" (weeks 4–12) is where most attrition happens; a visible achievement system with ongoing pull toward the next milestone is one of the strongest-evidenced interventions for sustaining engagement through this phase.

---

## Goals

- Recognise genuine progress at natural milestone points
- Give users something to look forward to throughout the 18-week journey
- Provide a permanent trophy shelf that validates past effort
- Never make achievements feel like participation prizes or game tokens

## Non-Goals

- Points, currency, or any transactional reward mechanic
- Global leaderboards or social comparison
- GameKit / Game Center (UI mismatch, privacy, limited per-exercise granularity)
- Achievements for trivial actions (logging in, completing onboarding)

---

## Achievement Categories

### 1. Milestone (Completion-Based)

Earned by completing meaningful program events.

| Achievement | Trigger |
|---|---|
| First workout | Complete any workout session |
| First test | Attempt any max-rep test |
| Level complete — \<exercise\> L1/L2/L3 | Pass the test for a given exercise level (18 possible) |
| Full program complete | All 6 exercises reach Level 3 |

*Note: "First workout" is the only participation-adjacent achievement. It is celebrated subtly (Tier 1 — no confetti) to avoid feeling patronising while still acknowledging the real friction of starting.*

### 2. Streak (Tiered)

Earned by maintaining consecutive training days. Uses existing `StreakCalculator` output.

| Tier | Days |
|---|---|
| Bronze | 3 |
| Silver | 7 |
| Gold | 14 |
| Platinum | 30 |
| Diamond | 60 |
| Obsidian | 100 |

Streak achievements display the **current streak count**, not a static badge. Losing a streak does not remove earned tier achievements — they represent "achieved at least once." The trophy shelf shows "Best streak: 24 days" alongside current streak.

### 3. Consistency (Session Count)

Earned by accumulating total completed sessions, globally and per-exercise.

| Achievement | Threshold |
|---|---|
| 5 sessions | 5 total |
| 10 sessions | 10 total |
| 25 sessions | 25 total |
| 50 sessions | 50 total |
| 100 sessions | 100 total |
| 10 \<exercise\> sessions | 10 sessions for a single exercise |

### 4. Performance (Mastery-Based)

Earned when actual performance exceeds a prior personal record.

| Achievement | Trigger |
|---|---|
| Personal best — \<exercise\> | Any session where total reps for that exercise exceeds the previous best |

Personal best achievements are repeatable — each new record replaces the previous one in the trophy shelf (showing the current best value), but the achievement unlock celebration fires each time.

### 5. Journey (Narrative)

Earned for program breadth and consistency patterns.

| Achievement | Trigger |
|---|---|
| The full set | Complete at least one session in every enrolled exercise within a single calendar week |
| Halfway there | 50% of enrolled exercises have reached Level 2 or higher |
| Test gauntlet | Pass max-rep tests for 3 different exercises |

---

## Data Model

### New `@Model`: `Achievement`

```swift
@Model
final class Achievement {
    var id: String                      // e.g. "streak_7", "level_complete_push_ups_l1"
    var category: String                // "milestone" | "streak" | "consistency" | "performance" | "journey"
    var unlockedAt: Date
    var exerciseId: String?             // nil for global achievements
    var numericValue: Int?              // reps for personal best, days for streak

    init(id: String, category: String, unlockedAt: Date,
         exerciseId: String? = nil, numericValue: Int? = nil) { ... }
}
```

### AchievementChecker Service

A new `AchievementChecker` in `Shared/Sources/InchShared/Engine/` evaluates achievement conditions against `ModelContext`. Called from `WorkoutViewModel` after each session saves, and from `TodayViewModel` on load.

```swift
struct AchievementChecker {
    func check(after event: AchievementEvent, in context: ModelContext) -> [Achievement]
}

enum AchievementEvent {
    case workoutCompleted(exerciseId: String, totalReps: Int, level: Int)
    case testPassed(exerciseId: String, level: Int)
    case streakUpdated(currentStreak: Int)
    case programComplete
}
```

Returns newly unlocked `Achievement` values (not yet persisted). The call site saves them and triggers the celebration UI.

---

## Celebration Design

Three tiers, calibrated to achievement significance:

### Tier 1 — Subtle acknowledgement
*For: first workout, first test, Bronze streak, personal best, 5/10 sessions*

- Inline banner slides up from the bottom of the post-workout summary screen
- Light haptic (`.success` on `UINotificationFeedbackGenerator`)
- Dismisses automatically after 4 seconds or on tap
- No modal, no interruption

### Tier 2 — Mid-level recognition
*For: Silver/Gold streak, 25/50 sessions, "The full set", "Halfway there"*

- Slide-up half-sheet with achievement badge (scale-in animation)
- Medium haptic
- "See all achievements" button
- User dismisses manually

### Tier 3 — Full celebration
*For: level completion, test pass, Platinum+ streak, 100 sessions, program complete*

- Full-screen overlay with achievement badge reveal
- Confetti particle effect via SwiftUI `Canvas` + `TimelineView` (no third-party library)
- Custom Core Haptics pattern — distinct from any other app feedback
- Share sheet offered: `UIActivityViewController` with a pre-rendered achievement card (`ImageRenderer`)
- "View trophy shelf" button
- Respects `UIAccessibility.isReduceMotionEnabled` — confetti replaced with a static glow effect

---

## Trophy Shelf

A new **Achievements** section added to the History tab (below the Stats segment, or as a third segment: Log / Stats / Achievements).

Layout:
- Grid of achievement badges, grouped by category
- **Earned:** full colour with unlock date and numeric value where relevant
- **Unearned:** grey silhouette with label visible — creates aspirational pull toward next milestone
- Tapping an earned achievement shows its detail (name, description, date earned)
- Tapping an unearned achievement shows what's required to earn it

The trophy shelf must be browseable at any time — not just surfaced at unlock. Research confirms this is the second-most important surface after the in-moment celebration.

---

## Surfacing Strategy

| Surface | What appears |
|---|---|
| Post-workout summary | In-moment celebration (Tier 1/2/3 depending on significance) |
| History log row | Small achievement badge inline on the row for sessions where an achievement was earned |
| Trophy shelf | Full collection, earned and unearned |
| Push notification | Only for Tier 3 achievements when app is not in foreground; max 1 notification per day |

Push notifications for achievements use the existing `NotificationService`. Gate strictly: only level completions, Platinum+ streak milestones, and program complete. Never push Bronze/Silver badge unlocks.

---

## Schema Migration

`Achievement` is a new `@Model` class. Adding it to the `ModelContainer` requires a `BodyweightSchemaV2` with a `MigrationStage.lightweight` stage. No data transformation is needed — the migration simply registers the new entity. This is the same migration that adds `seenExerciseInfo` to `UserSettings` and the adaptation fields to `ExerciseEnrolment`; they should be batched into one schema version bump.

## Implementation Details

### Deduplication
`AchievementChecker.check(after:in:)` queries existing `Achievement` records from `ModelContext` before returning results. An achievement is only returned (and subsequently persisted) if no record with the same `id` already exists. Exception: personal best achievements are always returned if the new value exceeds the stored `numericValue` — the call site updates the existing record's `numericValue` and `unlockedAt` in place (mutation, not delete-and-reinsert) to preserve the original unlock date in history. The trophy shelf displays the current best value from `numericValue`.

### Streak Evaluation
`AchievementChecker` reads `StreakState` directly from `ModelContext` for streak achievement checks. The caller does not need to pass the streak value — the checker derives it. This keeps the `AchievementEvent.streakUpdated` case simple (no associated value needed; the checker fetches the live value itself).

### Watch Completion Path
When a Watch workout completes and the report is later applied on iPhone (via `WatchConnectivityService.applyReport`), `AchievementChecker.check(after:in:)` runs after the session saves. If achievements are unlocked, they are persisted to `Achievement` silently — **no celebration UI fires** because the app may be backgrounded or the user may be on a different screen. The next time the user opens the app and the Today tab loads, a `pendingCelebrations: [Achievement]` property on `TodayViewModel` surfaces any uncelebrated achievements. The view presents them in sequence using a `.sheet` or overlay, beginning with the highest tier.

The `Achievement` model gains a `wasCelebrated: Bool = false` field. `AchievementChecker` sets it to `false` on creation; `TodayViewModel` sets it to `true` after displaying the celebration.

### TodayViewModel Achievement Surfacing
`TodayViewModel.loadToday()` queries `Achievement` records where `wasCelebrated == false` and populates `pendingCelebrations: [Achievement]`. The view presents these after the main Today content loads (slight delay to avoid jarring the user).

### History Row Badge
`Achievement` gains a `sessionDate: Date?` field — set to the `sessionDate` of the `CompletedSet` that triggered the unlock (passed by the call site). `HistoryLogView` queries achievements by `sessionDate` to show inline badges on matching history rows.

### Achievement Notifications
Add `achievementNotificationEnabled: Bool = true` to `UserSettings`. Batched into the same schema migration. The `NotificationService` gains a `scheduleAchievementNotification(for:)` method called only for Tier 3 achievements when the app is not foregrounded, subject to the user's preference and a maximum of 1 achievement notification per day.

### UIKit Replacements
- **Haptics:** Use `SensoryFeedback` (SwiftUI, iOS 17+) — `.success` for Tier 1/2, a custom `.impact(.heavy)` for Tier 3. No `UINotificationFeedbackGenerator`.
- **Share sheet:** Use SwiftUI `ShareLink` with a `Transferable` image payload rendered via `ImageRenderer`. No `UIActivityViewController`.

### Share Card
The Tier 3 share card is a 1080×1080pt SwiftUI view rendered to an image via `ImageRenderer`. Content: app logo mark, achievement name, achievement icon, user's current streak or rep count as context, and a subtle "Daily Ascent" wordmark. Exact visual design is a separate design task — implementation should accept a `ShareCardView` component that can be designed independently.

## Scope Boundaries

- SwiftData storage only — no GameKit, no server-side achievement sync
- iPhone only in v1; Watch surfaces uncelebrated achievements on next iPhone foreground (see Watch Completion Path above)
- No retroactive achievement unlocks on first install (achievements are earned going forward from the feature's release)
- "Personal best" tracks total reps per session per exercise — not per-set records
