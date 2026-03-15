# CLAUDE.md — Inch Bodyweight Training App

## Project Overview

Inch is an iOS + watchOS bodyweight training app with 6 exercises (Push-Ups, Squats, Sit-Ups, Pull-Ups, Glute Bridges, Dead Bugs), each with 3 progressive levels. Users enrol in exercises, follow prescribed set/rep schemes, and progress through levels by passing max-rep tests. The app features injury-aware scheduling, two rep counting modes, and collects anonymous sensor data for future ML-based auto rep counting.

## Worktrees

Use `.worktrees/` (project-local, hidden) for all git worktrees. This directory is gitignored.

## Specification Documents

Read these before writing any code. They are the source of truth for all features and architecture decisions.

| Document | Purpose | Read When |
|---|---|---|
| `Specs/bodyweight-ux-design-v2.md` | Full UX spec: screens, flows, scheduling rules, privacy, monetisation | Always — product requirements |
| `Specs/exercise-data.json` | All exercise progressions: 6 exercises, 18 levels, ~300 days | Building data loader or any UI showing sets/reps |
| `Specs/data-model.md` | SwiftData schema: all entities, relationships, enums, indexes, transfer DTOs | Building any data layer code |
| `Specs/scheduling-engine.md` | Scheduling algorithms with pseudocode and 12 test cases | Building the scheduling engine |
| `Specs/architecture.md` | Project structure, target config, state management, navigation, services | Always — structural decisions |
| `Specs/framework-guidance.md` | WatchConnectivity, Core Motion, HealthKit, BGProcessingTask patterns | Building framework integration |
| `Specs/backend-api.md` | Supabase schema, upload endpoints, client integration | Building the upload service |

## Build & Run

- **Xcode version:** 16.0+
- **Deployment targets:** iOS 18.0, watchOS 11.0
- **Swift version:** 6.2
- **Signing:** Automatic, development team configured in Xcode
- **Simulator:** Use iPhone 16 Pro and Apple Watch Series 10 for testing
- **No third-party dependencies** unless explicitly approved. The app uses only Apple frameworks.

## Agent Skills

The following agent skills are installed and must be followed:

- **SwiftUI Pro** — all UI patterns, navigation, state management
- **SwiftData Pro** — all data model code, queries, relationships
- **Swift Concurrency Pro** — all async code, actors, bridging
- **Swift Testing Pro** — all test code

When these skills conflict with the spec documents, the spec documents take precedence (they were written with the skills in mind).

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
- Use `#Index` on frequently queried properties
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

## Build Order

Follow this sequence. Each step should be complete with tests before starting the next.

1. **Shared package: Models + Enums** — SwiftData entities from `data-model.md`
2. **Shared package: ExerciseDataLoader** — parse `exercise-data.json`, seed ModelContext
3. **Shared package: SchedulingEngine** — all algorithms from `scheduling-engine.md`, full test coverage
4. **Shared package: ConflictDetector + Resolver** — conflict detection and resolution, tested
5. **Shared package: StreakCalculator** — streak logic, tested
6. **iOS app shell** — App entry point, ModelContainer, tab navigation, empty views
7. **Onboarding** — EnrolmentView, DataConsentView. Seeds data, creates enrolments.
8. **Today dashboard** — TodayView + TodayViewModel. Shows due exercises with conflict warnings.
9. **Workout session** — Both counting modes, rest timers, exercise completion, test day flow
10. **Program view** — Progress bars, exercise detail, level navigation
11. **Settings** — Rest timers, counting modes, privacy toggles
12. **WatchConnectivity** — iPhone service, schedule push, completion report handling
13. **Watch app** — Today view, workout flow, result sync
14. **HealthKit** — Authorization, workout logging
15. **Sensor recording** — Core Motion service on both devices, file management
16. **Background upload** — BGProcessingTask, Supabase upload pipeline
17. **Streak integration** — Wire calculator into dashboard and history

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
- Do not modify files in `Specs/` — they are read-only reference documents
