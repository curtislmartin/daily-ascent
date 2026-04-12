# CLAUDE.md — Daily Ascent Bodyweight Training App

## Project Overview

Daily Ascent is an iOS + watchOS bodyweight training app with 9 exercises (Push-Ups, Squats, Pull-Ups, Dips, Rows, Hip Hinge, Spinal Extension, Plank, Dead Bugs), each with 3 progressive levels. Users enrol in exercises, follow prescribed set/rep schemes, and progress through levels by passing max-rep tests. The app features injury-aware scheduling, two rep counting modes, and collects anonymous sensor data for future ML-based auto rep counting.

## Dev Resources

Supporting development resources live in a separate private repo: **`curtislmartin/daily-ascent-dev`**

All feature planning (specs, plans, design docs) lives in that repo. Check there for:
- **`docs/superpowers/plans/`** — implementation plans for all features built to date
- **`docs/superpowers/specs/`** — design specs for those features
- **`skills_repo/`** — Claude Code skills for SwiftUI, SwiftData, Swift Concurrency, Swift Testing, App Store, accessibility, and more
- **`todos/`** — resolved bug and improvement records
- **`audit.md`**, **`notes.md`** — development notes

Clone it adjacent to this repo if you need to reference it: `gh repo clone curtislmartin/daily-ascent-dev`

## Specification Documents

Read these before writing any code. They are the source of truth for all features and architecture decisions.

| Document | Purpose | Read When |
|---|---|---|
| `files/bodyweight-ux-design-v2.md` | Full UX spec: screens, flows, scheduling rules, privacy, monetisation | Always — product requirements |
| `Shared/Sources/InchShared/Resources/exercise-data.json` | All exercise progressions: 9 exercises, 27 levels | Building data loader or any UI showing sets/reps |
| `files/data-model.md` | SwiftData schema: all entities, relationships, enums, indexes, transfer DTOs | Building any data layer code |
| `files/scheduling-engine.md` | Scheduling algorithms with pseudocode and 12 test cases | Building the scheduling engine |
| `files/architecture.md` | Project structure, target config, state management, navigation, services | Always — structural decisions |
| `files/framework-guidance.md` | WatchConnectivity, Core Motion, HealthKit, BGProcessingTask patterns | Building framework integration |
| `files/backend-api.md` | Supabase schema, upload endpoints, client integration | Building the upload service |
| `files/v1-1-features.md` | v1.1 features: history, stats, notifications, complications, exercise detail, conflict warnings | Building any v1.1 feature |

## Build & Run

- **Xcode version:** 16.0+
- **Deployment targets:** iOS 18.0, watchOS 10.6
- **Swift version:** 6.2
- **Signing:** Automatic, development team configured in Xcode
- **Simulator:** Use iPhone 16 Pro and Apple Watch Series 10 for testing
- **No third-party dependencies** unless explicitly approved. The app uses only Apple frameworks.

## Code Style

### Swift Conventions
- Swift 6.2 with strict concurrency checking
- Main-actor default isolation enabled for both app targets (NOT the shared package)
- `@Observable` classes for view models — implicitly `@MainActor` in app targets
- Prefer `async`/`await` over GCD. No `DispatchQueue` anywhere. No Combine.
- Prefer `Double` over `CGFloat`
- Prefer `Date.now` over `Date()`
- Use `if let value {` shorthand
- Omit `return` for single-expression functions
- Never use `!` force unwrap — use `guard let`, `if let`, or `#require` in tests
- Never prefix test methods with `test`
- Use `#expect(value == false)` not `#expect(!value)` in tests

### File Organization
- One type per file, always
- Files named after the type they contain
- Feature-based folder structure (Today/, Workout/, Program/, etc.)
- Test folder structure mirrors source folder structure
- Extracted subviews in separate files, never computed properties returning `some View`

### SwiftData Specific
- Explicit `@Relationship(deleteRule:, inverse:)` on every relationship
- All properties have defaults or are optional (CloudKit-ready)
- No `@Attribute(.unique)` or `#Unique` (CloudKit-ready)
- Use `PersistentIdentifier` when passing model references across boundaries
- Call `save()` explicitly when correctness matters
- Never use `@Query` outside SwiftUI views

### Navigation
- `NavigationStack` with `navigationDestination(for:)` only
- No `NavigationLink(destination:)` — it's deprecated-pattern
- No `NavigationView` — it's deprecated
- Tab navigation uses `Tab("Label", systemImage:, value:)` with enum

### Concurrency
- Prefer structured concurrency (`withTaskGroup`) over `Task {}` in loops
- `@concurrent` for CPU-heavy work that should leave the main actor
- `AsyncStream` via `makeStream(of:)` for bridging delegate-based APIs
- `withCheckedContinuation` for single-shot callbacks
- Never use `@unchecked Sendable` to silence errors — fix the underlying issue
- Actor reentrancy: never assume state is unchanged after `await`

## Testing Strategy

All tests use Swift Testing, never XCTest (except UI tests if needed).

### Test Structure
- Test suites are `struct`, not `class`
- No `@Suite` annotation unless attaching traits
- `init()` for setup, not `setUp()`
- `#require` for preconditions, `#expect` for assertions
- Parameterized tests for data-driven scenarios (scheduling test cases)
- Tags: `.scheduling`, `.conflict`, `.streak`, `.dataLoader`, `.integration`

### What Must Be Tested
- **SchedulingEngine**: All 12 test cases from `scheduling-engine.md`, plus edge cases
- **ConflictDetector**: Double-test, same-group, cascade scenarios
- **ConflictResolver**: Priority ordering, push mechanics
- **StreakCalculator**: Partial completion, rest days, gaps, resets
- **ExerciseDataLoader**: JSON parsing, data integrity
- **View models**: State changes, not view rendering

### Test Tags

```swift
extension Tag {
    @Tag static var scheduling: Self
    @Tag static var conflict: Self
    @Tag static var streak: Self
    @Tag static var dataLoader: Self
    @Tag static var integration: Self
}
```

### Example Test Pattern

```swift
struct SchedulingEngineTests {
    let engine: SchedulingEngine
    
    init() {
        engine = SchedulingEngine()
    }
    
    @Test(.tags(.scheduling))
    func basicDateCalculation() throws {
        // From scheduling-engine.md Test 1
        let enrolment = makeTestEnrolment(
            exerciseId: "push_ups",
            level: 1,
            day: 1,
            lastCompleted: makeDate(2026, 3, 15),
            patternIndex: 0
        )
        
        let nextDate = try #require(engine.computeNextDate(for: enrolment))
        #expect(nextDate == makeDate(2026, 3, 17), "Gap should be 2 days (pattern[0])")
    }
    
    @Test(.tags(.scheduling), arguments: [
        (day: 1, index: 0, expectedGap: 2),
        (day: 2, index: 1, expectedGap: 2),
        (day: 3, index: 2, expectedGap: 3),
        (day: 4, index: 0, expectedGap: 2),  // pattern cycles
    ])
    func patternCycling(day: Int, index: Int, expectedGap: Int) throws {
        let baseDate = makeDate(2026, 3, 15)
        let enrolment = makeTestEnrolment(
            exerciseId: "push_ups",
            level: 1,
            day: day,
            lastCompleted: baseDate,
            patternIndex: index
        )
        
        let nextDate = try #require(engine.computeNextDate(for: enrolment))
        let gap = Calendar.current.dateComponents([.day], from: baseDate, to: nextDate).day
        #expect(gap == expectedGap, "Day \(day) with pattern index \(index) should have gap of \(expectedGap)")
    }
}
```

## What NOT To Do

- No UIKit (SwiftUI only, except where Apple frameworks require UIKit types)
- No Combine
- No Grand Central Dispatch
- No third-party packages without explicit approval
- No `NavigationView` or `NavigationLink(destination:)`
- No `@unchecked Sendable` to silence concurrency errors
- No `@StateObject`, `@ObservedObject`, `@EnvironmentObject`, `@Published`
- No force unwraps (`!`) in production code
- No XCTest for unit tests (Swift Testing only)
- No `Task.sleep(nanoseconds:)` — use `Task.sleep(for:)`
- No hardcoded API keys in source files
- No `.confirmationDialog` — use a centered card overlay instead (see `ResumePromptOverlay.swift` for the pattern)
- Do not modify files in `files/` — they are read-only reference documents
