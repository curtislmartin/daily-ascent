# Exercise Data Sync Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the one-shot `seedIfNeeded` with a `syncFromBundle` upsert so existing users automatically receive new exercises and updated catalogue data on every app launch.

**Architecture:** `ExerciseDataLoader.syncFromBundle(context:)` fetches all existing `ExerciseDefinition` rows into a dictionary keyed by `exerciseId`, then walks the JSON — inserting rows that don't exist and updating scalar fields on rows that do. Levels and days follow the same pattern keyed by `level` and `dayNumber` respectively. `inchApp.swift` calls `syncFromBundle` in its launch `.task` so all users (not just new ones) benefit.

**Tech Stack:** Swift 6.2, SwiftData, Swift Testing, InchShared package

---

## Chunk 1: Core upsert logic + isTest fix

### Task 1: Write tests for `syncFromBundle`

**Files:**
- Modify: `Shared/Tests/InchSharedTests/ExerciseDataLoaderTests.swift`

**Context:**

Write these tests first (TDD). `syncFromBundle` does not exist yet — all tests will fail with "value of type 'ExerciseDataLoader' has no member 'syncFromBundle'". That is the expected failure.

The test file is at `Shared/Tests/InchSharedTests/ExerciseDataLoaderTests.swift`. It uses `@testable import InchShared` and `ModelContainerFactory.makeContainer(inMemory: true)` for a fresh in-memory store per test. All existing tests call `seedIfNeeded`. The master branch JSON has **9 exercises**: `push_ups`, `squats`, `pull_ups`, `dead_bugs`, `hip_hinge`, `spinal_extension`, `plank`, `rows`, `dips`.

- [ ] **Step 1: Add the failing tests**

Append these methods to `ExerciseDataLoaderTests`:

```swift
@Test(.tags(.dataLoader))
func syncFromBundleOnEmptyDBLoadsAllExercises() throws {
    let container = try ModelContainerFactory.makeContainer(inMemory: true)
    let context = ModelContext(container)
    try ExerciseDataLoader().syncFromBundle(context: context)

    let exercises = try context.fetch(FetchDescriptor<ExerciseDefinition>())
    #expect(exercises.count == 9)
}

@Test(.tags(.dataLoader))
func syncFromBundleInsertsNewExercisesIntoExistingDB() throws {
    let container = try ModelContainerFactory.makeContainer(inMemory: true)
    let context = ModelContext(container)

    // Simulate existing user who only had the original 4 exercises
    let pushUps = ExerciseDefinition(exerciseId: "push_ups", name: "Push-Ups", sortOrder: 0)
    context.insert(pushUps)
    try context.save()

    try ExerciseDataLoader().syncFromBundle(context: context)

    let exercises = try context.fetch(FetchDescriptor<ExerciseDefinition>())
    #expect(exercises.count == 9)
    #expect(exercises.contains { $0.exerciseId == "hip_hinge" })
    #expect(exercises.contains { $0.exerciseId == "rows" })
    #expect(exercises.contains { $0.exerciseId == "dips" })
}

@Test(.tags(.dataLoader))
func syncFromBundleUpdatesChangedExerciseName() throws {
    let container = try ModelContainerFactory.makeContainer(inMemory: true)
    let context = ModelContext(container)

    let pushUps = ExerciseDefinition(exerciseId: "push_ups", name: "Old Name", sortOrder: 0)
    context.insert(pushUps)
    try context.save()

    try ExerciseDataLoader().syncFromBundle(context: context)

    let all = try context.fetch(FetchDescriptor<ExerciseDefinition>())
    let updated = try #require(all.first { $0.exerciseId == "push_ups" })
    #expect(updated.name == "Push-Ups")
}

@Test(.tags(.dataLoader))
func syncFromBundleIsIdempotent() throws {
    let container = try ModelContainerFactory.makeContainer(inMemory: true)
    let context = ModelContext(container)
    let loader = ExerciseDataLoader()
    try loader.syncFromBundle(context: context)
    try loader.syncFromBundle(context: context)

    let exercises = try context.fetch(FetchDescriptor<ExerciseDefinition>())
    #expect(exercises.count == 9)
}

@Test(.tags(.dataLoader))
func syncFromBundleSetsIsTestFromJSON() throws {
    let container = try ModelContainerFactory.makeContainer(inMemory: true)
    let context = ModelContext(container)
    try ExerciseDataLoader().syncFromBundle(context: context)

    // push_ups L1: day 10 is isTest per JSON; day 1 is not
    let all = try context.fetch(FetchDescriptor<ExerciseDefinition>())
    let pushUps = try #require(all.first { $0.exerciseId == "push_ups" })
    let level1 = try #require(pushUps.levels?.first { $0.level == 1 })
    let day10 = try #require(level1.days?.first { $0.dayNumber == 10 })
    #expect(day10.isTest == true)
    let day1 = try #require(level1.days?.first { $0.dayNumber == 1 })
    #expect(day1.isTest == false)
}
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
cd /Users/curtismartin/Work/inch-project
swift test --package-path Shared --filter ExerciseDataLoaderTests 2>&1 | grep -E '(passed|failed|error:)'
```

Expected: 5 new tests fail with compile error (method not found), existing tests pass.

---

### Task 2: Implement `syncFromBundle` and fix `DayDTO.isTest`

**Files:**
- Modify: `Shared/Sources/InchShared/Engine/ExerciseDataLoader.swift`

**Context:**

`ExerciseDataLoader` lives at `Shared/Sources/InchShared/Engine/ExerciseDataLoader.swift`. It has a `seedIfNeeded` method and private decoding types at the bottom. `LevelDefinition` and `LevelDTO` both have `variationName: String?` on the master branch.

Bug to fix: `DayDTO` has no `isTest` field, so the loader computes `isTest: dayDTO.day == levelDTO.totalDays`. The JSON has `"isTest": true` on the correct days. Add the field and use it.

- [ ] **Step 1: Add `isTest` to `DayDTO`**

Find the `DayDTO` struct at the bottom of `ExerciseDataLoader.swift`:
```swift
struct DayDTO: Decodable {
    let day: Int
    let sets: [Int]
}
```
Replace with:
```swift
struct DayDTO: Decodable {
    let day: Int
    let sets: [Int]
    let isTest: Bool?
}
```

- [ ] **Step 2: Fix `isTest` usage in `seedIfNeeded`**

In `seedIfNeeded`, find:
```swift
isTest: dayDTO.day == levelDTO.totalDays
```
Replace with:
```swift
isTest: dayDTO.isTest ?? (dayDTO.day == levelDTO.totalDays)
```

- [ ] **Step 3: Add `syncFromBundle` method**

After the closing brace of `seedIfNeeded`, add:

```swift
/// Upserts exercise catalogue from the bundled JSON.
/// Safe to call on every launch — inserts new exercises and updates changed fields.
/// Never touches user enrolments or progress data.
public func syncFromBundle(context: ModelContext) throws {
    guard let url = Bundle.module.url(forResource: "exercise-data", withExtension: "json") else {
        throw ExerciseDataError.jsonNotFound
    }
    let data = try Data(contentsOf: url)
    let root = try JSONDecoder().decode(ExerciseDataRoot.self, from: data)

    let existing = try context.fetch(FetchDescriptor<ExerciseDefinition>())
    let exerciseMap = Dictionary(uniqueKeysWithValues: existing.map { ($0.exerciseId, $0) })

    var dirty = false

    for (index, dto) in root.exercises.enumerated() {
        let exercise: ExerciseDefinition
        if let found = exerciseMap[dto.id] {
            exercise = found
            let mg = MuscleGroup(rawValue: dto.muscleGroup) ?? .upperPush
            let cm = CountingMode(rawValue: dto.countingMode) ?? .postSetConfirmation
            if exercise.name != dto.name                             { exercise.name = dto.name; dirty = true }
            if exercise.color != dto.color                           { exercise.color = dto.color; dirty = true }
            if exercise.muscleGroup != mg                            { exercise.muscleGroup = mg; dirty = true }
            if exercise.countingMode != cm                           { exercise.countingMode = cm; dirty = true }
            if exercise.defaultRestSeconds != dto.defaultRestSeconds { exercise.defaultRestSeconds = dto.defaultRestSeconds; dirty = true }
            if exercise.sortOrder != index                           { exercise.sortOrder = index; dirty = true }
        } else {
            exercise = ExerciseDefinition(
                exerciseId: dto.id,
                name: dto.name,
                muscleGroup: MuscleGroup(rawValue: dto.muscleGroup) ?? .upperPush,
                color: dto.color,
                countingMode: CountingMode(rawValue: dto.countingMode) ?? .postSetConfirmation,
                defaultRestSeconds: dto.defaultRestSeconds,
                sortOrder: index
            )
            context.insert(exercise)
            dirty = true
        }

        let levelMap = Dictionary(uniqueKeysWithValues: (exercise.levels ?? []).map { ($0.level, $0) })
        for levelDTO in dto.levels {
            let levelDef: LevelDefinition
            if let found = levelMap[levelDTO.level] {
                levelDef = found
                if levelDef.restDayPattern != levelDTO.restDayPattern           { levelDef.restDayPattern = levelDTO.restDayPattern; dirty = true }
                if levelDef.testTarget != levelDTO.testTarget                   { levelDef.testTarget = levelDTO.testTarget; dirty = true }
                if levelDef.extraRestBeforeTest != levelDTO.extraRestBeforeTest { levelDef.extraRestBeforeTest = levelDTO.extraRestBeforeTest; dirty = true }
                if levelDef.totalDays != levelDTO.totalDays                     { levelDef.totalDays = levelDTO.totalDays; dirty = true }
                if levelDef.variationName != levelDTO.variationName             { levelDef.variationName = levelDTO.variationName; dirty = true }
            } else {
                levelDef = LevelDefinition(
                    level: levelDTO.level,
                    restDayPattern: levelDTO.restDayPattern,
                    testTarget: levelDTO.testTarget,
                    extraRestBeforeTest: levelDTO.extraRestBeforeTest,
                    totalDays: levelDTO.totalDays,
                    variationName: levelDTO.variationName
                )
                levelDef.exercise = exercise
                context.insert(levelDef)
                dirty = true
            }

            let dayMap = Dictionary(uniqueKeysWithValues: (levelDef.days ?? []).map { ($0.dayNumber, $0) })
            for dayDTO in levelDTO.days {
                let isTest = dayDTO.isTest ?? (dayDTO.day == levelDTO.totalDays)
                if let found = dayMap[dayDTO.day] {
                    if found.sets != dayDTO.sets { found.sets = dayDTO.sets; dirty = true }
                    if found.isTest != isTest     { found.isTest = isTest; dirty = true }
                } else {
                    let day = DayPrescription(dayNumber: dayDTO.day, sets: dayDTO.sets, isTest: isTest)
                    day.level = levelDef
                    context.insert(day)
                    dirty = true
                }
            }
        }
    }

    if dirty { try context.save() }
}
```

- [ ] **Step 4: Run the tests**

```bash
cd /Users/curtismartin/Work/inch-project
swift test --package-path Shared --filter ExerciseDataLoaderTests 2>&1 | grep -E '(passed|failed|error:)'
```

Expected: all tests pass.

- [ ] **Step 5: Run full Shared test suite**

```bash
cd /Users/curtismartin/Work/inch-project
swift test --package-path Shared 2>&1 | tail -5
```

Expected: all tests pass, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add Shared/Sources/InchShared/Engine/ExerciseDataLoader.swift \
        Shared/Tests/InchSharedTests/ExerciseDataLoaderTests.swift
git commit -m "feat: add syncFromBundle upsert to ExerciseDataLoader; fix isTest from JSON"
```

---

## Chunk 2: Wire sync into app launch

### Task 3: Wire sync into app launch

**Files:**
- Modify: `inch/inch/inchApp.swift`
- Modify: `inch/inch/Features/Onboarding/OnboardingCoordinatorView.swift`

**Context:**

`inchApp.swift` has a `.task` block on `RootView` that runs on every launch. It already uses `withTaskGroup` to run background tasks. Add `syncFromBundle` as a third child task in that group — this matches the existing pattern and avoids Swift 6 concurrency issues that `Task.detached` would cause (since `ModelContext` is not `Sendable` across actor boundaries).

Also update `OnboardingCoordinatorView.swift` to call `syncFromBundle` instead of `seedIfNeeded`. The `if definitions.isEmpty` guard can stay — `syncFromBundle` handles empty DBs identically to `seedIfNeeded`.

- [ ] **Step 1: Add sync call to `inchApp.swift`**

In `inch/inch/inchApp.swift`, inside the `withTaskGroup` block in `.task`, add a third child task:

```swift
.task {
    watchConnectivity.activate()
    await notificationService.checkAuthorizationStatus()
    await withTaskGroup(of: Void.self) { group in
        group.addTask {
            let context = ModelContext(self.container)
            await self.watchConnectivity.handleCompletionReports(context: context)
        }
        group.addTask {
            let context = ModelContext(self.container)
            await self.watchConnectivity.handleReceivedFiles(context: context)
        }
        group.addTask {
            let context = ModelContext(self.container)
            try? ExerciseDataLoader().syncFromBundle(context: context)
        }
    }
}
```

- [ ] **Step 2: Update `OnboardingCoordinatorView` to use `syncFromBundle`**

In `inch/inch/Features/Onboarding/OnboardingCoordinatorView.swift`, find:

```swift
try? loader.seedIfNeeded(context: modelContext)
```

Replace with:

```swift
try? loader.syncFromBundle(context: modelContext)
```

- [ ] **Step 3: Build the iOS app to confirm it compiles**

```bash
cd /Users/curtismartin/Work/inch-project/inch
xcodebuild build \
  -scheme inch \
  -configuration Debug \
  -destination "generic/platform=iOS Simulator" \
  2>&1 | grep -E '(error:|BUILD SUCCEEDED|BUILD FAILED)'
```

Expected: `BUILD SUCCEEDED` with no errors.

- [ ] **Step 4: Commit**

```bash
git add inch/inch/inchApp.swift \
        inch/inch/Features/Onboarding/OnboardingCoordinatorView.swift
git commit -m "feat: sync exercise catalogue from bundle on every app launch"
```
