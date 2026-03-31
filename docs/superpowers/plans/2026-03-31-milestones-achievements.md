# Milestones & Achievements — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Recognise genuine user progress at natural milestone points — first workout, level completions, streak tiers, session counts, personal bests, and narrative journey achievements — with tiered celebration UI (inline banner, half-sheet, full-screen confetti) and a persistent trophy shelf in the History tab.

**Architecture:** `Achievement` is a new SwiftData `@Model`. `AchievementChecker` is a pure struct in `Shared` that queries `ModelContext` and returns newly unlocked achievements without persisting them — the call site persists. `WorkoutViewModel.completeSession()` calls the checker and stores results. `TodayViewModel` surfaces uncelebrated achievements as `pendingCelebrations` for Watch-completed sessions. Three celebration tiers are separate SwiftUI views. The trophy shelf is a new segment in `HistoryView`.

**Tech Stack:** SwiftData, SwiftUI `SensoryFeedback`, SwiftUI `Canvas` + `TimelineView` for confetti, `ShareLink` with `ImageRenderer` for Tier 3 share, `BodyweightSchemaV3` migration.

---

## Schema Migration Note

This plan adds: new `Achievement` `@Model` class; `achievementNotificationEnabled: Bool = true` on `UserSettings`. These go into `BodyweightSchemaV3` alongside changes from the other plans. Coordinate with Exercise Form Guidance plan (Task 1) and Retention Analytics plan (Task 1) to ensure V3 is created once and includes all new properties from all plans.

---

## File Map

| Action | File | Responsibility |
|---|---|---|
| Create | `Shared/Sources/InchShared/Models/Achievement.swift` | `@Model` class with id, category, unlockedAt, exerciseId?, numericValue?, wasCelebrated, sessionDate? |
| Modify | `Shared/Sources/InchShared/Models/BodyweightSchema.swift` | Add `Achievement.self` to `BodyweightSchemaV3.models` |
| Modify | `Shared/Sources/InchShared/Models/UserSettings.swift` | Add `achievementNotificationEnabled: Bool = true` |
| Create | `Shared/Sources/InchShared/Engine/AchievementChecker.swift` | Pure struct: `check(after:in:) -> [Achievement]`; deduplication logic |
| Modify | `inch/inch/Features/Workout/WorkoutViewModel.swift` | Call `AchievementChecker` in `completeSession()`; persist achievements; queue celebrations |
| Modify | `inch/inch/Features/Workout/ExerciseCompleteView.swift` | Show Tier 1/2 celebrations via passed-in achievements list |
| Create | `inch/inch/Features/Workout/AchievementBanner.swift` | Tier 1: inline slide-up banner, auto-dismisses after 4 seconds |
| Create | `inch/inch/Features/Workout/AchievementSheet.swift` | Tier 2: half-sheet with badge scale-in animation |
| Create | `inch/inch/Features/Workout/AchievementCelebrationView.swift` | Tier 3: full-screen overlay with confetti (Canvas + TimelineView) |
| Create | `inch/inch/Features/Workout/ConfettiView.swift` | Pure SwiftUI confetti particle effect |
| Create | `inch/inch/Features/Workout/ShareCardView.swift` | Tier 3 share card rendered via `ImageRenderer` |
| Modify | `inch/inch/Features/Today/TodayViewModel.swift` | Add `pendingCelebrations: [Achievement]`; query uncelebrated on load |
| Modify | `inch/inch/Features/Today/TodayView.swift` | Present pending celebrations as sheet overlay on appear |
| Create | `inch/inch/Features/History/TrophyShelfView.swift` | Grid of earned/unearned achievement badges |
| Modify | `inch/inch/Features/History/HistoryView.swift` | Add Achievements segment/tab; show `TrophyShelfView` |
| Modify | `inch/inch/Features/History/HistoryLogView.swift` | Inline achievement badge on session rows where `sessionDate` matches |
| Modify | `inch/inch/Services/NotificationService.swift` | Add `scheduleAchievementNotification(for:)` for Tier 3 only |
| Test | `Shared/Tests/InchSharedTests/AchievementCheckerTests.swift` | Unit tests for deduplication, personal best update, all trigger conditions |

---

### Task 1: Schema — `Achievement` model and `UserSettings.achievementNotificationEnabled`

**Files:**
- Create: `Shared/Sources/InchShared/Models/Achievement.swift`
- Modify: `Shared/Sources/InchShared/Models/BodyweightSchema.swift`
- Modify: `Shared/Sources/InchShared/Models/UserSettings.swift`

- [ ] **Step 1: Write the failing tests**

Create `Shared/Tests/InchSharedTests/AchievementCheckerTests.swift` (model tests first):

```swift
import Testing
@testable import InchShared

struct AchievementModelTests {

    @Test func defaultsToNotCelebrated() {
        let achievement = Achievement(
            id: "streak_7",
            category: "streak",
            unlockedAt: .now
        )
        #expect(achievement.wasCelebrated == false)
    }

    @Test func achievementNotificationEnabledDefaultsTrue() {
        let settings = UserSettings()
        #expect(settings.achievementNotificationEnabled == true)
    }
}
```

- [ ] **Step 2: Run to confirm tests fail**

```
swift test --package-path Shared --filter AchievementModelTests
```

Expected: FAIL — types not found.

- [ ] **Step 3: Create `Achievement.swift`**

```swift
import Foundation
import SwiftData

@Model
public final class Achievement {
    public var id: String = ""                  // e.g. "streak_7", "level_complete_push_ups_l1"
    public var category: String = ""            // "milestone" | "streak" | "consistency" | "performance" | "journey"
    public var unlockedAt: Date = Date.now
    public var exerciseId: String? = nil        // nil for global achievements
    public var numericValue: Int? = nil         // reps for personal best, days for streak
    public var wasCelebrated: Bool = false      // TodayViewModel sets true after showing celebration
    public var sessionDate: Date? = nil         // join key for history row badge

    public init(
        id: String,
        category: String,
        unlockedAt: Date = .now,
        exerciseId: String? = nil,
        numericValue: Int? = nil,
        sessionDate: Date? = nil
    ) {
        self.id = id
        self.category = category
        self.unlockedAt = unlockedAt
        self.exerciseId = exerciseId
        self.numericValue = numericValue
        self.wasCelebrated = false
        self.sessionDate = sessionDate
    }
}
```

- [ ] **Step 4: Add `achievementNotificationEnabled` to `UserSettings`**

Add after existing notification properties:
```swift
public var achievementNotificationEnabled: Bool = true
```

Add to `init` with default and assign in body.

- [ ] **Step 5: Add `Achievement.self` to `BodyweightSchemaV3.models`**

In `BodyweightSchema.swift`, find `BodyweightSchemaV3.models` and add `Achievement.self`:

```swift
public static var models: [any PersistentModel.Type] {
    [
        ExerciseDefinition.self,
        LevelDefinition.self,
        DayPrescription.self,
        ExerciseEnrolment.self,
        CompletedSet.self,
        SensorRecording.self,
        UserSettings.self,
        StreakState.self,
        UserEntitlement.self,
        Achievement.self    // new
    ]
}
```

If V3 doesn't exist yet, create it following the template in Exercise Form Guidance plan Task 1 Step 5, then add `Achievement.self`.

- [ ] **Step 6: Run tests to confirm they pass**

```
swift test --package-path Shared --filter AchievementModelTests
```

Expected: PASS

- [ ] **Step 7: Build app to verify**

```
xcodebuild build -project inch/inch.xcodeproj -scheme inch -destination 'generic/platform=iOS Simulator' | grep -E '(error:|Build succeeded)'
```

Expected: `Build succeeded`

- [ ] **Step 8: Commit**

```bash
git add Shared/Sources/InchShared/Models/Achievement.swift \
        Shared/Sources/InchShared/Models/BodyweightSchema.swift \
        Shared/Sources/InchShared/Models/UserSettings.swift \
        Shared/Tests/InchSharedTests/AchievementCheckerTests.swift
git commit -m "$(cat <<'EOF'
feat: add Achievement model and achievementNotificationEnabled to SchemaV3

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Create `AchievementChecker`

**Files:**
- Create: `Shared/Sources/InchShared/Engine/AchievementChecker.swift`

- [ ] **Step 1: Write the failing checker tests**

Add to `Shared/Tests/InchSharedTests/AchievementCheckerTests.swift`:

```swift
import Testing
import SwiftData
@testable import InchShared

struct AchievementCheckerTests {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Schema(BodyweightSchemaV3.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test func firstWorkoutUnlockedOnFirstCompletion() throws {
        let context = try makeContext()
        let checker = AchievementChecker()
        let event = AchievementEvent.workoutCompleted(
            exerciseId: "push_ups", totalReps: 30, level: 1, sessionDate: .now
        )
        let results = checker.check(after: event, in: context)
        #expect(results.contains { $0.id == "first_workout" })
    }

    @Test func firstWorkoutNotDuplicatedOnSecondCompletion() throws {
        let context = try makeContext()
        // Pre-insert the first_workout achievement
        let existing = Achievement(id: "first_workout", category: "milestone", unlockedAt: .now)
        context.insert(existing)
        try context.save()

        let checker = AchievementChecker()
        let event = AchievementEvent.workoutCompleted(
            exerciseId: "push_ups", totalReps: 30, level: 1, sessionDate: .now
        )
        let results = checker.check(after: event, in: context)
        #expect(results.allSatisfy { $0.id != "first_workout" })
    }

    @Test func personalBestReturnedWhenRepsExceedPrior() throws {
        let context = try makeContext()
        // Pre-insert a personal best with numericValue = 25
        let prior = Achievement(
            id: "personal_best_push_ups",
            category: "performance",
            unlockedAt: .now.addingTimeInterval(-86400),
            exerciseId: "push_ups",
            numericValue: 25
        )
        context.insert(prior)
        try context.save()

        let checker = AchievementChecker()
        let event = AchievementEvent.workoutCompleted(
            exerciseId: "push_ups", totalReps: 35, level: 1, sessionDate: .now
        )
        let results = checker.check(after: event, in: context)
        #expect(results.contains { $0.id == "personal_best_push_ups" && $0.numericValue == 35 })
    }

    @Test func personalBestNotReturnedWhenRepsLower() throws {
        let context = try makeContext()
        let prior = Achievement(
            id: "personal_best_push_ups",
            category: "performance",
            unlockedAt: .now.addingTimeInterval(-86400),
            exerciseId: "push_ups",
            numericValue: 40
        )
        context.insert(prior)
        try context.save()

        let checker = AchievementChecker()
        let event = AchievementEvent.workoutCompleted(
            exerciseId: "push_ups", totalReps: 35, level: 1, sessionDate: .now
        )
        let results = checker.check(after: event, in: context)
        #expect(results.allSatisfy { $0.id != "personal_best_push_ups" })
    }

    @Test func streakAchievementUnlockedAtThreshold() throws {
        let context = try makeContext()
        // Set up a StreakState with streak = 7
        let streak = StreakState()
        streak.currentStreak = 7
        context.insert(streak)
        try context.save()

        let checker = AchievementChecker()
        let event = AchievementEvent.streakUpdated
        let results = checker.check(after: event, in: context)
        #expect(results.contains { $0.id == "streak_7" })
    }
}
```

- [ ] **Step 2: Run to confirm tests fail**

```
swift test --package-path Shared --filter AchievementCheckerTests
```

Expected: FAIL — `AchievementChecker` not found.

- [ ] **Step 3: Create `AchievementChecker.swift`**

```swift
import Foundation
import SwiftData

public enum AchievementEvent {
    case workoutCompleted(exerciseId: String, totalReps: Int, level: Int, sessionDate: Date)
    case testPassed(exerciseId: String, level: Int, sessionDate: Date)
    case streakUpdated
    case programComplete
}

public struct AchievementChecker {
    public init() {}

    /// Evaluates achievement conditions against ModelContext.
    /// Returns newly unlocked Achievement values — NOT yet persisted.
    /// The call site is responsible for inserting them and saving context.
    /// Personal best achievements are returned with updated numericValue
    /// but NOT yet mutated in context — call site must update the existing record.
    public func check(after event: AchievementEvent, in context: ModelContext) -> [Achievement] {
        var unlocked: [Achievement] = []

        // Fetch all existing achievements for deduplication
        let existing = (try? context.fetch(FetchDescriptor<Achievement>())) ?? []
        let existingIds = Set(existing.map(\.id))

        switch event {
        case let .workoutCompleted(exerciseId, totalReps, level, sessionDate):
            // Milestone: first_workout
            if !existingIds.contains("first_workout") {
                unlocked.append(Achievement(
                    id: "first_workout", category: "milestone",
                    unlockedAt: .now, sessionDate: sessionDate
                ))
            }

            // Consistency: total session counts
            let totalSessions = completedSessionCount(in: context)
            for threshold in [5, 10, 25, 50, 100] {
                let id = "sessions_\(threshold)"
                if totalSessions >= threshold && !existingIds.contains(id) {
                    unlocked.append(Achievement(
                        id: id, category: "consistency",
                        unlockedAt: .now, sessionDate: sessionDate
                    ))
                }
            }

            // Consistency: per-exercise session count (10)
            let exerciseSessions = completedSessionCount(for: exerciseId, in: context)
            let exerciseCountId = "sessions_10_\(exerciseId)"
            if exerciseSessions >= 10 && !existingIds.contains(exerciseCountId) {
                unlocked.append(Achievement(
                    id: exerciseCountId, category: "consistency",
                    unlockedAt: .now, exerciseId: exerciseId, sessionDate: sessionDate
                ))
            }

            // Performance: personal best
            let pbId = "personal_best_\(exerciseId)"
            if let existing = existing.first(where: { $0.id == pbId }) {
                if totalReps > (existing.numericValue ?? 0) {
                    // Return with updated value — call site mutates existing record
                    let updated = Achievement(
                        id: pbId, category: "performance",
                        unlockedAt: .now, exerciseId: exerciseId,
                        numericValue: totalReps, sessionDate: sessionDate
                    )
                    unlocked.append(updated)
                }
            } else if totalReps > 0 {
                unlocked.append(Achievement(
                    id: pbId, category: "performance",
                    unlockedAt: .now, exerciseId: exerciseId,
                    numericValue: totalReps, sessionDate: sessionDate
                ))
            }

            // Journey: the full set (check separately — complex query)
            checkFullSet(existingIds: existingIds, sessionDate: sessionDate,
                        context: context, into: &unlocked)

        case let .testPassed(exerciseId, level, sessionDate):
            // Milestone: first_test
            if !existingIds.contains("first_test") {
                unlocked.append(Achievement(
                    id: "first_test", category: "milestone",
                    unlockedAt: .now, sessionDate: sessionDate
                ))
            }
            // Milestone: level complete
            let levelId = "level_complete_\(exerciseId)_l\(level)"
            if !existingIds.contains(levelId) {
                unlocked.append(Achievement(
                    id: levelId, category: "milestone",
                    unlockedAt: .now, exerciseId: exerciseId,
                    numericValue: level, sessionDate: sessionDate
                ))
            }
            // Journey: test_gauntlet (3 different exercises passed)
            checkTestGauntlet(existingIds: existingIds, newExercise: exerciseId,
                             context: context, sessionDate: sessionDate, into: &unlocked)
            // Milestone: full program complete
            checkProgramComplete(existingIds: existingIds, context: context,
                                sessionDate: sessionDate, into: &unlocked)

        case .streakUpdated:
            let streak = (try? context.fetch(FetchDescriptor<StreakState>()))?.first
            let current = streak?.currentStreak ?? 0
            for (threshold, tier) in [(3, "bronze"), (7, "silver"), (14, "gold"),
                                       (30, "platinum"), (60, "diamond"), (100, "obsidian")] {
                let id = "streak_\(threshold)"
                if current >= threshold && !existingIds.contains(id) {
                    unlocked.append(Achievement(
                        id: id, category: "streak",
                        unlockedAt: .now, numericValue: current
                    ))
                }
            }

        case .programComplete:
            if !existingIds.contains("program_complete") {
                unlocked.append(Achievement(
                    id: "program_complete", category: "milestone", unlockedAt: .now
                ))
            }
        }

        return unlocked
    }

    // MARK: - Private helpers

    private func completedSessionCount(in context: ModelContext) -> Int {
        // Count distinct session dates across all CompletedSets
        let sets = (try? context.fetch(FetchDescriptor<CompletedSet>())) ?? []
        let dates = Set(sets.map { Calendar.current.startOfDay(for: $0.sessionDate) })
        return dates.count
    }

    private func completedSessionCount(for exerciseId: String, in context: ModelContext) -> Int {
        let predicate = #Predicate<CompletedSet> { $0.exerciseId == exerciseId }
        let sets = (try? context.fetch(FetchDescriptor<CompletedSet>(predicate: predicate))) ?? []
        let dates = Set(sets.map { Calendar.current.startOfDay(for: $0.sessionDate) })
        return dates.count
    }

    private func checkFullSet(existingIds: Set<String>, sessionDate: Date,
                               context: ModelContext, into results: inout [Achievement]) {
        guard !existingIds.contains("the_full_set") else { return }
        // Check if all enrolled exercises have a CompletedSet in the same calendar week
        let enrolments = (try? context.fetch(
            FetchDescriptor<ExerciseEnrolment>(predicate: #Predicate { $0.isActive })
        )) ?? []
        guard !enrolments.isEmpty else { return }
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: sessionDate)?.start ?? sessionDate
        let weekEnd = Calendar.current.dateInterval(of: .weekOfYear, for: sessionDate)?.end ?? sessionDate
        let exerciseIds = Set(enrolments.compactMap { $0.exerciseDefinition?.exerciseId })
        let setsThisWeek = (try? context.fetch(FetchDescriptor<CompletedSet>(
            predicate: #Predicate<CompletedSet> { $0.sessionDate >= weekStart && $0.sessionDate < weekEnd }
        ))) ?? []
        let completedThisWeek = Set(setsThisWeek.map(\.exerciseId))
        if exerciseIds.isSubset(of: completedThisWeek) {
            results.append(Achievement(
                id: "the_full_set", category: "journey",
                unlockedAt: .now, sessionDate: sessionDate
            ))
        }
    }

    private func checkTestGauntlet(existingIds: Set<String>, newExercise: String,
                                    context: ModelContext, sessionDate: Date,
                                    into results: inout [Achievement]) {
        guard !existingIds.contains("test_gauntlet") else { return }
        let existingAchievements = (try? context.fetch(FetchDescriptor<Achievement>())) ?? []
        let passedExercises = Set(
            existingAchievements
                .filter { $0.category == "milestone" && $0.id.hasPrefix("level_complete_") }
                .compactMap { $0.exerciseId }
        )
        let allPassed = passedExercises.union([newExercise])
        if allPassed.count >= 3 {
            results.append(Achievement(
                id: "test_gauntlet", category: "journey",
                unlockedAt: .now, sessionDate: sessionDate
            ))
        }
    }

    private func checkProgramComplete(existingIds: Set<String>, context: ModelContext,
                                       sessionDate: Date, into results: inout [Achievement]) {
        guard !existingIds.contains("program_complete") else { return }
        let enrolments = (try? context.fetch(
            FetchDescriptor<ExerciseEnrolment>(predicate: #Predicate { $0.isActive })
        )) ?? []
        let allLevel3 = enrolments.allSatisfy { $0.currentLevel > 3 || $0.currentDay > 18 }
        if !enrolments.isEmpty && allLevel3 {
            results.append(Achievement(
                id: "program_complete", category: "milestone",
                unlockedAt: .now, sessionDate: sessionDate
            ))
        }
    }
}
```

> **Note:** `CompletedSet.sessionDate` and `exerciseId` must be properties on `CompletedSet`. Read `CompletedSet.swift` to confirm the exact property names before writing queries.

- [ ] **Step 4: Run tests to confirm they pass**

```
swift test --package-path Shared --filter AchievementCheckerTests
```

Expected: All PASS. Fix any failures before continuing.

- [ ] **Step 5: Commit**

```bash
git add Shared/Sources/InchShared/Engine/AchievementChecker.swift \
        Shared/Tests/InchSharedTests/AchievementCheckerTests.swift
git commit -m "$(cat <<'EOF'
feat: add AchievementChecker with full deduplication and personal best logic

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Hook `AchievementChecker` into `WorkoutViewModel`

**Files:**
- Modify: `inch/inch/Features/Workout/WorkoutViewModel.swift`

- [ ] **Step 1: Call `AchievementChecker` in `completeSession(context:)`**

Add at the end of `completeSession(context:)`, after `phase = .complete`:

```swift
// Run achievement check after session saves
let checker = AchievementChecker()
let sessionDateCopy = sessionDate
let exerciseIdCopy = enrolment.exerciseDefinition?.exerciseId ?? ""
let levelCopy = completedLevel
let repsCopy = sessionTotalReps
let didAdvance = didAdvanceLevel
let testDayFlag = isTestDay

// Check for workout-based achievements
var newAchievements = checker.check(
    after: .workoutCompleted(
        exerciseId: exerciseIdCopy,
        totalReps: repsCopy,
        level: levelCopy,
        sessionDate: sessionDateCopy
    ),
    in: context
)

// If level advanced via test day, also check test-passed achievements
if testDayFlag && didAdvance {
    newAchievements += checker.check(
        after: .testPassed(
            exerciseId: exerciseIdCopy,
            level: levelCopy,
            sessionDate: sessionDateCopy
        ),
        in: context
    )
}

// Persist new achievements
for achievement in newAchievements {
    // Personal best: update existing record instead of inserting duplicate
    if achievement.category == "performance",
       let existing = (try? context.fetch(FetchDescriptor<Achievement>(
           predicate: #Predicate<Achievement> { $0.id == achievement.id }
       )))?.first {
        existing.numericValue = achievement.numericValue
        existing.unlockedAt = .now
    } else {
        context.insert(achievement)
    }
}
try? context.save()
pendingAchievements = newAchievements
```

Add a `pendingAchievements: [Achievement] = []` property to `WorkoutViewModel`. `ExerciseCompleteView` will read this to decide which celebration to show.

- [ ] **Step 2: Build to verify**

```
xcodebuild build -project inch/inch.xcodeproj -scheme inch -destination 'generic/platform=iOS Simulator' | grep -E '(error:|Build succeeded)'
```

Expected: `Build succeeded`

- [ ] **Step 3: Commit**

```bash
git add inch/inch/Features/Workout/WorkoutViewModel.swift
git commit -m "$(cat <<'EOF'
feat: call AchievementChecker in WorkoutViewModel.completeSession

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Celebration UI (Tier 1, 2, 3) and `ExerciseCompleteView` wiring

**Files:**
- Create: `inch/inch/Features/Workout/AchievementBanner.swift`
- Create: `inch/inch/Features/Workout/AchievementSheet.swift`
- Create: `inch/inch/Features/Workout/ConfettiView.swift`
- Create: `inch/inch/Features/Workout/AchievementCelebrationView.swift`
- Modify: `inch/inch/Features/Workout/ExerciseCompleteView.swift`

- [ ] **Step 1: Create `AchievementBanner.swift` (Tier 1)**

```swift
import SwiftUI

struct AchievementBanner: View {
    let achievement: Achievement
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline).fontWeight(.semibold)
                Text(subtitle)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .sensoryFeedback(.success, trigger: true)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                onDismiss()
            }
        }
        .onTapGesture { onDismiss() }
    }

    private var iconName: String { "star.fill" }

    private var title: String {
        switch achievement.category {
        case "streak": return "Streak milestone!"
        case "consistency": return "Session milestone!"
        case "performance": return "Personal best!"
        default: return "Achievement unlocked!"
        }
    }

    private var subtitle: String { achievement.id.replacingOccurrences(of: "_", with: " ").capitalized }
}
```

- [ ] **Step 2: Create `ConfettiView.swift`**

```swift
import SwiftUI

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                for particle in particles {
                    let elapsed = timeline.date.timeIntervalSinceReferenceDate - particle.startTime
                    let progress = min(elapsed / 3.0, 1.0)
                    let x = particle.x * size.width + sin(particle.wobble + progress * 10) * 20
                    let y = particle.startY + progress * (size.height * 1.2)
                    let opacity = progress < 0.7 ? 1.0 : (1.0 - progress) / 0.3
                    context.opacity = opacity
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - 4, y: y - 6, width: 8, height: 12)),
                        with: .color(particle.color)
                    )
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            particles = (0..<80).map { _ in ConfettiParticle() }
        }
    }
}

struct ConfettiParticle {
    let x = Double.random(in: 0...1)
    let startY = Double.random(in: -100...0)
    let wobble = Double.random(in: 0...(.pi * 2))
    let startTime = Date.now.timeIntervalSinceReferenceDate
    let color: Color = [.red, .orange, .yellow, .green, .blue, .purple].randomElement()!
}
```

- [ ] **Step 3: Create `AchievementCelebrationView.swift` (Tier 3)**

```swift
import SwiftUI

struct AchievementCelebrationView: View {
    let achievement: Achievement
    let onDismiss: () -> Void
    @State private var badgeScale: Double = 0.1

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()

            if !UIAccessibility.isReduceMotionEnabled {
                ConfettiView()
            } else {
                // Reduce motion: static glow
                Circle()
                    .fill(.yellow.opacity(0.3))
                    .frame(width: 300, height: 300)
                    .blur(radius: 40)
            }

            VStack(spacing: 32) {
                Spacer()
                Image(systemName: "trophy.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.yellow)
                    .scaleEffect(badgeScale)
                    .onAppear {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                            badgeScale = 1.0
                        }
                    }
                    .sensoryFeedback(.impact(.heavy), trigger: true)

                VStack(spacing: 8) {
                    Text("Achievement Unlocked")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(achievement.id.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.title2).fontWeight(.bold).foregroundStyle(.white)
                }

                Spacer()

                VStack(spacing: 12) {
                    ShareLink(
                        item: achievementShareText,
                        subject: Text("Daily Ascent Achievement"),
                        message: Text(achievementShareText)
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("View Trophy Shelf") { onDismiss() }
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
    }

    private var achievementShareText: String {
        "I just unlocked \"\(achievement.id.replacingOccurrences(of: "_", with: " ").capitalized)\" on Daily Ascent! 💪"
    }
}
```

- [ ] **Step 4: Wire celebrations into `ExerciseCompleteView`**

`ExerciseCompleteView` currently takes `exerciseName`, `totalReps`, `previousSessionReps`, `nextDate`, `onDone`. Add `achievements: [Achievement] = []` parameter and show celebrations:

```swift
struct ExerciseCompleteView: View {
    let exerciseName: String
    let totalReps: Int
    let previousSessionReps: Int?
    let nextDate: Date?
    let achievements: [Achievement]
    let onDone: () -> Void

    @State private var showBanner = false
    @State private var showSheet = false
    @State private var showCelebration = false
    @State private var currentAchievement: Achievement?

    // Tier classification
    private var tier1: [Achievement] { achievements.filter { isTier1($0) } }
    private var tier2: [Achievement] { achievements.filter { isTier2($0) } }
    private var tier3: [Achievement] { achievements.filter { isTier3($0) } }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Existing content
            existingContent

            // Tier 1 banner (overlay at bottom)
            if showBanner, let a = tier1.first {
                AchievementBanner(achievement: a) { showBanner = false }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showSheet) {
            if let a = tier2.first {
                AchievementSheetContent(achievement: a) { showSheet = false }
            }
        }
        .fullScreenCover(isPresented: $showCelebration) {
            if let a = tier3.first {
                AchievementCelebrationView(achievement: a) { showCelebration = false }
            }
        }
        .onAppear { triggerCelebrations() }
    }

    private func triggerCelebrations() {
        // Tier 3 first (most significant)
        if !tier3.isEmpty {
            showCelebration = true
        } else if !tier2.isEmpty {
            showSheet = true
        } else if !tier1.isEmpty {
            withAnimation { showBanner = true }
        }
    }

    // ... existing body content extracted to existingContent computed property ...
}
```

Read the full current `ExerciseCompleteView` and extract the existing `VStack` body into a `private var existingContent: some View` computed property.

- [ ] **Step 5: Pass `achievements` from WorkoutViewModel**

In `WorkoutSessionView`, when navigating to `ExerciseCompleteView`, pass `viewModel.pendingAchievements`.

- [ ] **Step 6: Build and verify**

```
xcodebuild build -project inch/inch.xcodeproj -scheme inch -destination 'generic/platform=iOS Simulator' | grep -E '(error:|Build succeeded)'
```

Expected: `Build succeeded`

- [ ] **Step 7: Commit**

```bash
git add inch/inch/Features/Workout/AchievementBanner.swift \
        inch/inch/Features/Workout/ConfettiView.swift \
        inch/inch/Features/Workout/AchievementCelebrationView.swift \
        inch/inch/Features/Workout/ExerciseCompleteView.swift \
        inch/inch/Features/Workout/WorkoutSessionView.swift
git commit -m "$(cat <<'EOF'
feat: add three-tier achievement celebration UI

Tier 1: auto-dismissing banner. Tier 2: half-sheet.
Tier 3: full-screen confetti overlay with share sheet.
Respects isReduceMotionEnabled.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Trophy shelf, history badges, pending celebrations, notifications

**Files:**
- Create: `inch/inch/Features/History/TrophyShelfView.swift`
- Modify: `inch/inch/Features/History/HistoryView.swift`
- Modify: `inch/inch/Features/History/HistoryLogView.swift`
- Modify: `inch/inch/Features/Today/TodayViewModel.swift`
- Modify: `inch/inch/Features/Today/TodayView.swift`
- Modify: `inch/inch/Services/NotificationService.swift`

- [ ] **Step 1: Create `TrophyShelfView`**

```swift
import SwiftUI
import SwiftData

struct TrophyShelfView: View {
    @Query private var achievements: [Achievement]

    // All possible achievement IDs — shown as greyed silhouettes if not yet earned
    private let allIds: [(id: String, label: String, category: String)] = [
        ("first_workout", "First Workout", "milestone"),
        ("first_test", "First Test", "milestone"),
        ("streak_3", "3-Day Streak", "streak"),
        ("streak_7", "7-Day Streak", "streak"),
        ("streak_14", "14-Day Streak", "streak"),
        ("streak_30", "30-Day Streak", "streak"),
        ("streak_60", "60-Day Streak", "streak"),
        ("streak_100", "100-Day Streak", "streak"),
        ("sessions_5", "5 Sessions", "consistency"),
        ("sessions_10", "10 Sessions", "consistency"),
        ("sessions_25", "25 Sessions", "consistency"),
        ("sessions_50", "50 Sessions", "consistency"),
        ("sessions_100", "100 Sessions", "consistency"),
        ("the_full_set", "The Full Set", "journey"),
        ("test_gauntlet", "Test Gauntlet", "journey"),
        ("program_complete", "Program Complete", "milestone"),
    ]

    var body: some View {
        let earnedIds = Set(achievements.map(\.id))
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 20) {
                ForEach(allIds, id: \.id) { item in
                    let earned = earnedIds.contains(item.id)
                    let achievement = achievements.first { $0.id == item.id }
                    TrophyBadge(label: item.label, earned: earned, achievement: achievement)
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
                .foregroundStyle(earned ? .yellow : .secondary.opacity(0.4))
            Text(label)
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(earned ? .primary : .secondary.opacity(0.5))
            if let numericValue = achievement?.numericValue, earned {
                Text("\(numericValue)")
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
                    Text("Not yet earned")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Add Achievements segment to `HistoryView`**

Read `HistoryView.swift`. It likely has a `Picker` segment for Log/Stats. Add "Achievements":

```swift
case .achievements:
    TrophyShelfView()
```

- [ ] **Step 3: Add achievement badges to `HistoryLogView`**

In the session row rendering in `HistoryLogView`, query achievements where `sessionDate` matches the row's session date and show a small badge:

```swift
@Query private var allAchievements: [Achievement]

// In session row:
let rowAchievements = allAchievements.filter {
    guard let aDate = $0.sessionDate else { return false }
    return Calendar.current.isDate(aDate, inSameDayAs: sessionDate)
}
if !rowAchievements.isEmpty {
    Image(systemName: "trophy.fill")
        .font(.caption)
        .foregroundStyle(.yellow)
}
```

- [ ] **Step 4: Add `pendingCelebrations` to `TodayViewModel` for Watch sessions**

In `TodayViewModel`:
```swift
private(set) var pendingCelebrations: [Achievement] = []

// In loadToday():
let uncelebrated = (try? context.fetch(
    FetchDescriptor<Achievement>(predicate: #Predicate { !$0.wasCelebrated })
)) ?? []
pendingCelebrations = uncelebrated
```

In `TodayView`, show pending celebrations as overlays with a brief delay after load. Mark them as celebrated when shown:
```swift
.task {
    // Small delay to let Today content load first
    try? await Task.sleep(for: .seconds(1))
    // Present first pending celebration
}
```

- [ ] **Step 5: Build and test end-to-end on simulator**

Complete a workout that should trigger an achievement. Verify the celebration fires on `ExerciseCompleteView`. Check the trophy shelf — the earned badge should be coloured.

- [ ] **Step 6: Commit**

```bash
git add inch/inch/Features/History/TrophyShelfView.swift \
        inch/inch/Features/History/HistoryView.swift \
        inch/inch/Features/History/HistoryLogView.swift \
        inch/inch/Features/Today/TodayViewModel.swift \
        inch/inch/Features/Today/TodayView.swift
git commit -m "$(cat <<'EOF'
feat: add trophy shelf, history row badges, and pending celebration surfacing

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Tier classification helper

Add this as a private extension or free function (can live in `ExerciseCompleteView.swift`):

```swift
private func isTier1(_ a: Achievement) -> Bool {
    let tier1Ids = ["first_workout", "first_test", "streak_3",
                    "sessions_5", "sessions_10"]
    return tier1Ids.contains(a.id) || a.id.hasPrefix("personal_best_")
}
private func isTier2(_ a: Achievement) -> Bool {
    let tier2Ids = ["streak_7", "streak_14", "sessions_25", "sessions_50",
                    "the_full_set", "halfway_there"]
    return tier2Ids.contains(a.id)
}
private func isTier3(_ a: Achievement) -> Bool {
    let tier3Ids = ["streak_30", "streak_60", "streak_100", "sessions_100",
                    "program_complete", "test_gauntlet"]
    return tier3Ids.contains(a.id) || a.id.hasPrefix("level_complete_")
}
```
