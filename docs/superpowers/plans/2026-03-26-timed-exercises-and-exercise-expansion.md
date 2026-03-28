# Timed Exercises & Exercise Expansion Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add timed exercise mode (planks, spinal extension, handstands, wall sits, etc.), a hip hinge progression, spinal extension progression, rows, dips, and remove sit-ups — all without breaking existing users' data.

**Architecture:** We extend the data model with a v2 schema migration, adding `variationName` to `LevelDefinition`. For timed exercises, `CountingMode.timed` is added to the `CountingMode` enum. Timed exercises use **the existing `sets: [Int]` field to store target seconds per set** (e.g. `[20, 20, 20]` = 3 sets of 20s), keeping set counting and advancement logic identical to rep-based exercises. No new `durationSeconds` field is needed on `DayPrescription` — `countingMode == .timed` is the sole signal for timed mode. Exercise data JSON gains optional `variationName` per level. All existing code paths remain unchanged for rep-based exercises.

**Tech Stack:** SwiftData (migration v1→v2), SwiftUI, Swift 6.2, InchShared package, watchOS 10.6, exercise-data.json

---

## Scope Check

This plan covers three separable subsystems. Each could be its own plan, but they share one schema migration so are bundled:

1. **Schema v2 migration** — enables everything else; must ship first
2. **Timed exercise mode** — new UI + counting mode; works for any exercise once schema ready
3. **Exercise data changes** — JSON updates; safe once new loader supports new fields

All three must be implemented together in one release because the JSON expansion requires the new loader, and the loader requires the schema.

---

## File Structure

### Files to Create

| File | Purpose |
|------|---------|
| `Shared/Sources/InchShared/Models/BodyweightSchemaV2.swift` | V2 versioned schema + migration plan (replaces BodyweightSchema.swift pattern) |
| `inch/inch/Features/Workout/TimedSetView.swift` | Active hold timer UI (countdown + elapsed, stop button) |
| `inch/inch/Features/Workout/PreSetCountdownView.swift` | Pre-set countdown before a timed hold begins |
| `inch/inchwatch Watch App/Features/WatchTimedSetView.swift` | Watch equivalent of TimedSetView |
| `inch/inch/Features/Settings/TimedExerciseSettingsView.swift` | Settings screen for pre-set countdown duration |

### Files to Modify

| File | Change |
|------|--------|
| `Shared/Sources/InchShared/Models/Enums.swift` | Add `CountingMode.timed` case |
| `Shared/Sources/InchShared/Models/LevelDefinition.swift` | Add `variationName: String? = nil` |
| `Shared/Sources/InchShared/Models/DayPrescription.swift` | **No schema change.** `sets: [Int]` stores seconds for timed exercises. Add `isTimed: Bool` computed property (always false until `CountingMode` is checked — see note below). |
| `Shared/Sources/InchShared/Models/CompletedSet.swift` | Add `targetDurationSeconds: Int? = nil` only — existing `setDurationSeconds: Double?` stores the actual hold duration for timed sets |
| `Shared/Sources/InchShared/Models/UserSettings.swift` | Add `timedPrepCountdownSeconds: Int = 5` |
| `Shared/Sources/InchShared/Models/BodyweightSchema.swift` | Bump to V2, add lightweight migration stage |
| `Shared/Sources/InchShared/Utilities/ModelContainerFactory.swift` | Use V2 schema + `migrationPlan: BodyweightMigrationPlan.self` |
| `Shared/Sources/InchShared/Engine/ExerciseDataLoader.swift` | Parse `variationName`, `durationSeconds` from JSON |
| `Shared/Sources/InchShared/Transfer/WatchSession.swift` | Add `variationName: String?` only — `sets` already carries target seconds for timed exercises |
| `inch/inch/Features/Workout/WorkoutViewModel.swift` | Handle timed prescription; new `phase` for timed hold |
| `inch/inch/Features/Workout/WorkoutSessionView.swift` | Render `TimedSetView` + `PreSetCountdownView`; pass duration to viewModel |
| `inch/inch/Features/Workout/RestTimerView.swift` | Show "Next: Xs hold" instead of reps for timed exercises |
| `inch/inch/Features/Workout/TestDayView.swift` | Timed test mode: user holds as long as possible |
| `inch/inch/Features/Workout/WorkoutSounds.swift` | No change needed (existing sounds fine) |
| `inch/inch/Features/Settings/SettingsView.swift` | Add "Timed Exercises" row under Workout section |
| `inch/inchwatch Watch App/Features/WatchWorkoutView.swift` | Render `WatchTimedSetView` for timed mode |
| `inch/inchwatch Watch App/Features/WatchWorkoutViewModel.swift` | Handle timed prescription |
| `Shared/Sources/InchShared/Resources/exercise-data.json` (copy in `inch/inch/Resources/`) | Add new exercises, remove sit_ups, add variationName/durationSeconds |
| `Shared/Tests/InchSharedTests/ExerciseDataLoaderTests.swift` | Tests for new JSON fields |

> **IMPORTANT:** The exercise-data.json file lives at `inch/inch/Resources/exercise-data.json` (iOS bundle) and is loaded from `Bundle.module` in the shared package tests. Check both locations.

---

## Chunk 1: Schema Migration V2

### Task 1: Add `CountingMode.timed` to Enums

**Files:**
- Modify: `Shared/Sources/InchShared/Models/Enums.swift`

This is a no-op schema migration — adding a new enum case with a default value is backward-compatible.

- [ ] **Step 1: Open `Enums.swift` and add the new case**

```swift
public enum CountingMode: String, Codable, Sendable {
    case realTime = "real_time"
    case postSetConfirmation = "post_set_confirmation"
    case timed = "timed"
}
```

- [ ] **Step 2: Check all switch statements on `CountingMode` are exhaustive**

Search for `switch.*countingMode\|switch.*CountingMode` — every existing switch must handle `.timed` or use `default`. Files to check:
- `inch/inch/Features/Workout/WorkoutViewModel.swift` (the `countingMode` computed var returns from a definition, no switch needed)
- `inch/inch/Features/Today/TodayView.swift` — no switch
- `inch/inchwatch Watch App/Features/WatchWorkoutView.swift` — has `session.countingMode == "real_time"` string comparison, not a switch, fine for now

- [ ] **Step 3: Build to confirm no exhaustiveness errors**

```bash
cd /Users/curtismartin/Work/inch-project && xcodebuild build \
  -scheme "inch" \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  -configuration Debug 2>&1 | grep -E "error:|warning:|BUILD" | tail -20
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add Shared/Sources/InchShared/Models/Enums.swift
git commit -m "feat: add CountingMode.timed enum case"
```

---

### Task 2: Add `variationName` to `LevelDefinition`; update `CompletedSet`, `UserSettings`, and schema migration

**Files:**
- Modify: `Shared/Sources/InchShared/Models/LevelDefinition.swift`
- Modify: `Shared/Sources/InchShared/Models/DayPrescription.swift`

Both new fields have defaults (`nil`), making this a lightweight migration — SwiftData handles it automatically.

- [ ] **Step 1: Add `variationName` to `LevelDefinition`**

Replace the full file content:

```swift
import SwiftData

@Model
public final class LevelDefinition {
    public var level: Int = 1
    public var restDayPattern: [Int] = [2, 2, 3]
    public var testTarget: Int = 0
    public var extraRestBeforeTest: Int? = nil
    public var totalDays: Int = 0
    public var variationName: String? = nil   // e.g. "Hip Thrust" for level 3 of hip hinge

    public var exercise: ExerciseDefinition?

    @Relationship(deleteRule: .cascade, inverse: \DayPrescription.level)
    public var days: [DayPrescription]? = []

    public init(level: Int = 1, restDayPattern: [Int] = [2, 2, 3], testTarget: Int = 0, extraRestBeforeTest: Int? = nil, totalDays: Int = 0, variationName: String? = nil) {
        self.level = level
        self.restDayPattern = restDayPattern
        self.testTarget = testTarget
        self.extraRestBeforeTest = extraRestBeforeTest
        self.totalDays = totalDays
        self.variationName = variationName
    }
}
```

- [ ] **Step 2: No schema change to `DayPrescription` — add `isTimed` note only**

`DayPrescription` requires **no schema migration**. The existing `sets: [Int]` field carries target seconds for timed exercises (e.g. `[20, 20, 20]` = 3 × 20s holds). This keeps `totalSets`, `advanceAfterSet`, and all set-counting logic identical for timed and rep exercises.

`DayPrescription.isTimed` cannot be computed on the model itself (it doesn't have a reference to the parent `ExerciseDefinition`). Instead, `WorkoutViewModel.isTimedExercise: Bool { countingMode == .timed }` provides this at the view layer. No changes needed to `DayPrescription.swift`.

> **Design note:** `DayPrescription.totalReps` will return the sum of seconds for timed days (e.g. 60 for `[20, 20, 20]`). History and stats that display `totalReps` must guard on `countingMode == .timed` — this is handled in Task 14.

- [ ] **Step 3: Add `targetDurationSeconds` to `CompletedSet`**

`CompletedSet` already has `setDurationSeconds: Double?` which we repurpose as the actual hold duration for timed sets. We only need ONE new field — the prescribed target:

Open `Shared/Sources/InchShared/Models/CompletedSet.swift` and add after `setDurationSeconds`:

```swift
public var targetDurationSeconds: Int? = nil  // prescribed hold duration (nil for rep-based sets)
```

Add to `init` parameter list with default `nil`:

```swift
targetDurationSeconds: Int? = nil
```

Add to init body:

```swift
self.targetDurationSeconds = targetDurationSeconds
```

> **Naming convention for timed sets:**
> - `targetDurationSeconds: Int?` — the prescribed hold (e.g. 20s from the program)
> - `setDurationSeconds: Double?` — the actual time the user held (already exists, reused for timed mode)
> - For timed sets: `targetReps = 0`, `actualReps = 0` (unused)

- [ ] **Step 4: Add `timedPrepCountdownSeconds` to `UserSettings`**

Open `Shared/Sources/InchShared/Models/UserSettings.swift` and:
1. Add property after `dualDeviceRecordingEnabled`:
   ```swift
   public var timedPrepCountdownSeconds: Int = 5
   ```
2. Add to init parameter list with default `5`:
   ```swift
   timedPrepCountdownSeconds: Int = 5
   ```
3. Add to init body:
   ```swift
   self.timedPrepCountdownSeconds = timedPrepCountdownSeconds
   ```

- [ ] **Step 5: Update the schema to V2**

Replace `Shared/Sources/InchShared/Models/BodyweightSchema.swift` entirely:

```swift
import SwiftData

// V1 schema — preserved for migration chain
public enum BodyweightSchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)
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
            UserEntitlement.self
        ]
    }
}

// V2 schema — adds variationName, durationSeconds, timedPrepCountdownSeconds
// All new fields have defaults (nil or value), so this is a lightweight migration.
public enum BodyweightSchemaV2: VersionedSchema {
    public static let versionIdentifier = Schema.Version(2, 0, 0)
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
            UserEntitlement.self
        ]
    }
}

public enum BodyweightMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [BodyweightSchemaV1.self, BodyweightSchemaV2.self]
    }
    public static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    // Lightweight migration: all new columns have defaults, no custom logic needed.
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: BodyweightSchemaV1.self,
        toVersion: BodyweightSchemaV2.self
    )
}
```

- [ ] **Step 6: Update `ModelContainerFactory` to use V2 schema and migration plan**

Open `Shared/Sources/InchShared/Utilities/ModelContainerFactory.swift`. The current code passes `BodyweightSchemaV1.models` and does NOT wire the migration plan — meaning migrations never run. Replace with:

```swift
import SwiftData

public enum ModelContainerFactory {
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(BodyweightSchemaV2.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(
            for: schema,
            migrationPlan: BodyweightMigrationPlan.self,
            configurations: [config]
        )
    }
}
```

> **Why this matters:** Without `migrationPlan:`, SwiftData performs an implicit schema check but skips the versioned migration logic. Passing the migration plan explicitly tells SwiftData to apply the V1→V2 lightweight stage for existing users upgrading from an older build. New installs start directly at V2.

- [ ] **Step 7: Build to confirm schema compiles**

```bash
cd /Users/curtismartin/Work/inch-project && xcodebuild build \
  -scheme "inch" \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  -configuration Debug 2>&1 | grep -E "error:|BUILD" | tail -20
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 8: Commit**

```bash
git add \
  Shared/Sources/InchShared/Models/LevelDefinition.swift \
  Shared/Sources/InchShared/Models/DayPrescription.swift \
  Shared/Sources/InchShared/Models/CompletedSet.swift \
  Shared/Sources/InchShared/Models/UserSettings.swift \
  Shared/Sources/InchShared/Models/BodyweightSchema.swift \
  Shared/Sources/InchShared/Utilities/ModelContainerFactory.swift
git commit -m "feat: schema v2 — variationName, durationSeconds, timed prep countdown; wire migration plan"
```

---

## Chunk 2: Data Loader + Exercise JSON

### Task 3: Update `ExerciseDataLoader` to parse new fields

**Files:**
- Modify: `Shared/Sources/InchShared/Engine/ExerciseDataLoader.swift`
- Test: `Shared/Tests/InchSharedTests/ExerciseDataLoaderTests.swift`

The loader parses JSON into DTOs, creates SwiftData models. We need it to pass `variationName` to `LevelDefinition` and `durationSeconds` to `DayPrescription`.

- [ ] **Step 1: Write failing tests for new fields**

Open `Shared/Tests/InchSharedTests/ExerciseDataLoaderTests.swift` and add:

```swift
@Test(.tags(.dataLoader))
func variationNameParsedForLevels() throws {
    // Make DTOs internal (step 3) before this will compile.
    // We decode the DTO directly — no ModelContext needed.
    let json = """
    {
      "exercises": [{
        "id": "hip_hinge",
        "name": "Hip Hinge",
        "muscleGroup": "lower_posterior",
        "color": "#A0522D",
        "countingMode": "post_set_confirmation",
        "defaultRestSeconds": 90,
        "levels": [{
          "level": 1,
          "variationName": "Glute Bridge",
          "restDayPattern": [2, 2, 3],
          "testTarget": 30,
          "totalDays": 10,
          "days": [{"day": 1, "sets": [10, 10, 10]}]
        }]
      }]
    }
    """
    let data = try #require(json.data(using: .utf8))
    let root = try JSONDecoder().decode(ExerciseDataRoot.self, from: data)
    let level = try #require(root.exercises.first?.levels.first)
    #expect(level.variationName == "Glute Bridge")
}

@Test(.tags(.dataLoader))
func variationNameNilWhenAbsent() throws {
    let json = """
    {
      "exercises": [{
        "id": "push_ups",
        "name": "Push-Ups",
        "muscleGroup": "upper_push",
        "color": "#E8722A",
        "countingMode": "post_set_confirmation",
        "defaultRestSeconds": 60,
        "levels": [{
          "level": 1,
          "restDayPattern": [2, 2, 3],
          "testTarget": 20,
          "totalDays": 1,
          "days": [{"day": 1, "sets": [5, 5, 5]}]
        }]
      }]
    }
    """
    let data = try #require(json.data(using: .utf8))
    let root = try JSONDecoder().decode(ExerciseDataRoot.self, from: data)
    let level = try #require(root.exercises.first?.levels.first)
    #expect(level.variationName == nil)
}

@Test(.tags(.dataLoader))
func timedExerciseSetsStoredAsSeconds() throws {
    // Timed exercises use the existing sets: [Int] field — values are seconds, not reps.
    let json = """
    {
      "exercises": [{
        "id": "plank",
        "name": "Plank",
        "muscleGroup": "core_stability",
        "color": "#5B8A72",
        "countingMode": "timed",
        "defaultRestSeconds": 90,
        "levels": [{
          "level": 1,
          "restDayPattern": [2, 2, 3],
          "testTarget": 60,
          "totalDays": 1,
          "days": [{"day": 1, "sets": [20, 20, 20]}]
        }]
      }]
    }
    """
    let data = try #require(json.data(using: .utf8))
    let root = try JSONDecoder().decode(ExerciseDataRoot.self, from: data)
    let day = try #require(root.exercises.first?.levels.first?.days.first)
    #expect(day.sets == [20, 20, 20])  // 3 sets of 20 seconds
}
```

> **Note:** `ExerciseDataRoot` is currently `private`. The next step changes it to `internal` so `@testable import InchShared` exposes it to tests.

- [ ] **Step 2: Run tests — expect failures**

```bash
cd /Users/curtismartin/Work/inch-project && swift test --package-path Shared \
  --filter "ExerciseDataLoaderTests" 2>&1 | tail -20
```

Expected: compile errors or test failures because `variationName` and `durationSeconds` don't exist in DTOs yet.

- [ ] **Step 3: Update `ExerciseDataLoader.swift`**

Make DTOs internal (remove `private`), then add new fields:

```swift
import Foundation
import SwiftData

public struct ExerciseDataLoader: Sendable {
    public init() {}

    public func seedIfNeeded(context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<ExerciseDefinition>())
        guard existing.isEmpty else { return }

        guard let url = Bundle.module.url(forResource: "exercise-data", withExtension: "json") else {
            throw ExerciseDataError.jsonNotFound
        }
        let data = try Data(contentsOf: url)
        let root = try JSONDecoder().decode(ExerciseDataRoot.self, from: data)

        for (index, dto) in root.exercises.enumerated() {
            let exercise = ExerciseDefinition(
                exerciseId: dto.id,
                name: dto.name,
                muscleGroup: MuscleGroup(rawValue: dto.muscleGroup) ?? .upperPush,
                color: dto.color,
                countingMode: CountingMode(rawValue: dto.countingMode) ?? .postSetConfirmation,
                defaultRestSeconds: dto.defaultRestSeconds,
                sortOrder: index
            )
            context.insert(exercise)

            for levelDTO in dto.levels {
                let levelDef = LevelDefinition(
                    level: levelDTO.level,
                    restDayPattern: levelDTO.restDayPattern,
                    testTarget: levelDTO.testTarget,
                    extraRestBeforeTest: levelDTO.extraRestBeforeTest,
                    totalDays: levelDTO.totalDays,
                    variationName: levelDTO.variationName    // NEW
                )
                levelDef.exercise = exercise
                context.insert(levelDef)

                for dayDTO in levelDTO.days {
                    let day = DayPrescription(
                        dayNumber: dayDTO.day,
                        sets: dayDTO.sets,           // UNCHANGED — seconds for timed, reps for rep-based
                        isTest: dayDTO.day == levelDTO.totalDays
                    )
                    day.level = levelDef
                    context.insert(day)
                }
            }
        }

        try context.save()
    }
}

public enum ExerciseDataError: Error {
    case jsonNotFound
}

// MARK: - Decoding types (internal for testability)

struct ExerciseDataRoot: Decodable {
    let exercises: [ExerciseDTO]
}

struct ExerciseDTO: Decodable {
    let id: String
    let name: String
    let muscleGroup: String
    let color: String
    let countingMode: String
    let defaultRestSeconds: Int
    let levels: [LevelDTO]
}

struct LevelDTO: Decodable {
    let level: Int
    let restDayPattern: [Int]
    let testTarget: Int
    let extraRestBeforeTest: Int?
    let totalDays: Int
    let variationName: String?       // NEW — optional
    let days: [DayDTO]
}

struct DayDTO: Decodable {
    let day: Int
    let sets: [Int]                  // UNCHANGED — for timed days, values are target seconds per set
}
```

> **No `durationSeconds` field in the DTO.** Timed exercises use `sets: [Int]` with second values (`[20, 20, 20]` = 3 sets of 20s). This is the same JSON format as rep exercises — `countingMode: "timed"` on the exercise distinguishes interpretation.

- [ ] **Step 4: Fix test file — use `ExerciseDataRoot` (not `ExerciseDataRootTestable`)**

Update the three test cases to use `ExerciseDataRoot` directly (now accessible via `@testable import InchShared`). Remove `ExerciseDataRootTestable` references.

- [ ] **Step 5: Run tests — expect pass**

```bash
cd /Users/curtismartin/Work/inch-project && swift test --package-path Shared \
  --filter "ExerciseDataLoaderTests" 2>&1 | tail -20
```

Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add \
  Shared/Sources/InchShared/Engine/ExerciseDataLoader.swift \
  Shared/Tests/InchSharedTests/ExerciseDataLoaderTests.swift
git commit -m "feat: data loader parses variationName and durationSeconds from JSON"
```

---

### Task 4: Update `WatchSession` transfer DTO

**Files:**
- Modify: `Shared/Sources/InchShared/Transfer/WatchSession.swift` (find path with `find`)

The Watch needs to know the variation name (to display it) and whether a set is timed.

- [ ] **Step 1: Find the WatchSession file**

```bash
find /Users/curtismartin/Work/inch-project -name "WatchSession.swift" 2>/dev/null
```

- [ ] **Step 2: Add `variationName` and `durationSeconds` fields**

Open the file and add to the struct:

```swift
public struct WatchSession: Codable, Sendable {
    public let exerciseId: String
    public let exerciseName: String
    public let color: String
    public let level: Int
    public let dayNumber: Int
    public let sets: [Int]            // UNCHANGED — seconds for timed, reps for rep-based
    public let isTest: Bool
    public let testTarget: Int?
    public let restSeconds: Int
    public let countingMode: String   // "timed" for timed exercises; watch branches on this
    public let variationName: String? // NEW — nil for exercises without per-level variations
```

Update `init` to include `variationName: String? = nil`.

- [ ] **Step 3: Find where `WatchSession` instances are created (iPhone side) and update**

```bash
find /Users/curtismartin/Work/inch-project -name "*.swift" | xargs grep -l "WatchSession(" 2>/dev/null
```

For each call site, add `variationName: levelDef?.variationName, durationSeconds: prescription?.durationSeconds`.

- [ ] **Step 4: Build the full project to verify no compile errors**

```bash
cd /Users/curtismartin/Work/inch-project && xcodebuild build \
  -scheme "inch" \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  -configuration Debug 2>&1 | grep -E "error:|BUILD" | tail -20
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: Commit**

```bash
git add Shared/Sources/InchShared/Transfer/WatchSession.swift
git commit -m "feat: WatchSession carries variationName and durationSeconds"
```

---

### Task 5: Update exercise-data.json with new exercises

**Files:**
- Modify: `inch/inch/Resources/exercise-data.json` (this is the canonical bundled file)

**Exercises to add:**
- `hip_hinge` (replaces standalone `glute_bridges`) — 3 levels: Glute Bridge → Single-Leg Glute Bridge → Hip Thrust
- `spinal_extension` — 3 levels: Superman Hold → Back Extension → Weighted Back Extension (no weights: use slow tempo as substitute)
- `plank` — 3 levels of plank progressions (timed)
- `rows` — 3 levels using a table or low bar (bodyweight rows / Australian rows / archer rows)
- `dips` — 3 levels: bench dips → chair dips → parallel bar dips

**Exercises to remove:**
- `sit_ups` — replaced by `dead_bugs` for spinal flexion

**Hip hinge progression detail** (replaces glute_bridges):
- The exercise ID changes from `glute_bridges` to `hip_hinge`
- Level 1 variationName: "Glute Bridge" — floor glute bridges, 2 legs
- Level 2 variationName: "Single-Leg Glute Bridge" — same floor position, one leg
- Level 3 variationName: "Hip Thrust" — shoulder on bench, barbell optional but use bodyweight
- MuscleGroup: `lower_posterior`
- countingMode: `post_set_confirmation`

**Spinal extension** (anti-flexion complement):
- Level 1 variationName: "Superman Hold" — floor prone, arms forward, hold for count
- Level 2 variationName: "Back Extension" — off edge of surface or hyperextension machine
- Level 3 variationName: "Slow Back Extension" — same with 3s up, 3s down tempo
- MuscleGroup: `lower_posterior`
- countingMode: `post_set_confirmation` (rep-based, each rep = one slow hold)

**Plank** (core stability timed):
- Level 1 variationName: "Plank" — standard forearm plank, timed holds
- Level 2 variationName: "Extended Plank" — hands further forward, harder lever
- Level 3 variationName: "Feet-Elevated Plank" — feet on bench
- MuscleGroup: `core_stability`
- countingMode: `timed`
- Sets use `durationSeconds` (no `sets` reps array)
- testTarget for timed = target hold in seconds (e.g. 60s for L1, 90s for L2, 120s for L3)

**Rows** (horizontal pull):
- Level 1 variationName: "Table Row" — under a table, body at 45°
- Level 2 variationName: "Australian Row" — lower bar, body more horizontal
- Level 3 variationName: "Archer Row" — one arm emphasis
- MuscleGroup: `upper_pull`
- countingMode: `post_set_confirmation`

**Dips** (upper push complement to push-ups):
- Level 1 variationName: "Bench Dip" — hands on bench behind, feet on floor
- Level 2 variationName: "Chair Dip" — hands on two chairs, feet on floor
- Level 3 variationName: "Parallel Bar Dip" — full dips between parallel bars or chairs
- MuscleGroup: `upper_push`
- countingMode: `post_set_confirmation`

> **Note on variationName in JSON:** For exercises with a single consistent form across all levels (push_ups, pull_ups, squats, dead_bugs), omit `variationName` entirely (it will be `null` in the model). Only include it when the exercise form changes per level.

- [ ] **Step 1: Remove `sit_ups` from exercise-data.json**

Open `inch/inch/Resources/exercise-data.json`. Delete the entire `sit_ups` entry (the object in the `"exercises"` array where `"id": "sit_ups"`).

- [ ] **Step 2: Rename `glute_bridges` to `hip_hinge` and add variationNames**

Find the `glute_bridges` entry. Change:
- `"id"` from `"glute_bridges"` to `"hip_hinge"`
- `"name"` from `"Glute Bridges"` to `"Hip Hinge"`
- Add `"variationName": "Glute Bridge"` to level 1
- Add `"variationName": "Single-Leg Glute Bridge"` to level 2 (if exists; create new level data if not)
- Add `"variationName": "Hip Thrust"` to level 3 (if exists; create new level data if not)

Keep existing set/rep progressions for Level 1 (they're already correct for glute bridges). Adjust L2 and L3 rep counts to be lower since single-leg and hip thrust are harder.

**Level 2 suggested prescription** (Single-Leg Glute Bridge):
```json
{
  "level": 2,
  "variationName": "Single-Leg Glute Bridge",
  "restDayPattern": [2, 2, 3],
  "testTarget": 20,
  "totalDays": 10,
  "days": [
    {"day": 1, "sets": [5, 5, 4, 5, 4]},
    {"day": 2, "sets": [6, 6, 5, 5, 4]},
    {"day": 3, "sets": [7, 6, 6, 5, 5]},
    {"day": 4, "sets": [8, 7, 6, 6, 5]},
    {"day": 5, "sets": [9, 8, 7, 6, 5]},
    {"day": 6, "sets": [10, 8, 8, 7, 6]},
    {"day": 7, "sets": [11, 10, 8, 8, 7]},
    {"day": 8, "sets": [12, 10, 10, 8, 8]},
    {"day": 9, "sets": [14, 12, 10, 10, 8]},
    {"day": 10, "sets": []}
  ]
}
```

**Level 3 suggested prescription** (Hip Thrust):
```json
{
  "level": 3,
  "variationName": "Hip Thrust",
  "restDayPattern": [2, 2, 3],
  "testTarget": 20,
  "totalDays": 10,
  "days": [
    {"day": 1, "sets": [8, 8, 6, 8, 6]},
    {"day": 2, "sets": [9, 8, 8, 7, 6]},
    {"day": 3, "sets": [10, 9, 8, 8, 7]},
    {"day": 4, "sets": [11, 10, 9, 8, 7]},
    {"day": 5, "sets": [12, 10, 10, 9, 8]},
    {"day": 6, "sets": [13, 12, 10, 10, 8]},
    {"day": 7, "sets": [14, 12, 12, 10, 9]},
    {"day": 8, "sets": [15, 14, 12, 12, 10]},
    {"day": 9, "sets": [16, 14, 14, 12, 10]},
    {"day": 10, "sets": []}
  ]
}
```

- [ ] **Step 3: Add `spinal_extension` exercise**

```json
{
  "id": "spinal_extension",
  "name": "Spinal Extension",
  "muscleGroup": "lower_posterior",
  "color": "#8B6914",
  "countingMode": "post_set_confirmation",
  "defaultRestSeconds": 60,
  "levels": [
    {
      "level": 1,
      "variationName": "Superman Hold",
      "restDayPattern": [2, 2, 3],
      "testTarget": 20,
      "totalDays": 10,
      "days": [
        {"day": 1, "sets": [5, 5, 4, 5, 4]},
        {"day": 2, "sets": [6, 5, 5, 5, 4]},
        {"day": 3, "sets": [6, 6, 5, 5, 5]},
        {"day": 4, "sets": [7, 6, 6, 5, 5]},
        {"day": 5, "sets": [8, 7, 6, 6, 5]},
        {"day": 6, "sets": [9, 8, 7, 6, 6]},
        {"day": 7, "sets": [10, 8, 8, 7, 6]},
        {"day": 8, "sets": [11, 10, 8, 8, 7]},
        {"day": 9, "sets": [12, 10, 10, 8, 8]},
        {"day": 10, "sets": []}
      ]
    },
    {
      "level": 2,
      "variationName": "Back Extension",
      "restDayPattern": [2, 2, 3],
      "testTarget": 20,
      "totalDays": 10,
      "days": [
        {"day": 1, "sets": [5, 5, 4, 5, 4]},
        {"day": 2, "sets": [6, 5, 5, 5, 4]},
        {"day": 3, "sets": [7, 6, 6, 5, 5]},
        {"day": 4, "sets": [8, 7, 6, 6, 5]},
        {"day": 5, "sets": [9, 8, 7, 6, 6]},
        {"day": 6, "sets": [10, 8, 8, 7, 6]},
        {"day": 7, "sets": [11, 10, 8, 8, 7]},
        {"day": 8, "sets": [12, 10, 10, 8, 8]},
        {"day": 9, "sets": [14, 12, 10, 10, 8]},
        {"day": 10, "sets": []}
      ]
    },
    {
      "level": 3,
      "variationName": "Slow Back Extension",
      "restDayPattern": [2, 2, 3],
      "testTarget": 20,
      "totalDays": 10,
      "days": [
        {"day": 1, "sets": [6, 5, 5, 5, 4]},
        {"day": 2, "sets": [7, 6, 6, 5, 5]},
        {"day": 3, "sets": [8, 7, 6, 6, 5]},
        {"day": 4, "sets": [9, 8, 7, 6, 6]},
        {"day": 5, "sets": [10, 8, 8, 7, 6]},
        {"day": 6, "sets": [11, 10, 8, 8, 7]},
        {"day": 7, "sets": [12, 10, 10, 8, 8]},
        {"day": 8, "sets": [13, 12, 10, 10, 8]},
        {"day": 9, "sets": [14, 12, 12, 10, 8]},
        {"day": 10, "sets": []}
      ]
    }
  ]
}
```

- [ ] **Step 4: Add `plank` exercise (timed)**

Timed exercises use `sets: [Int]` where values are **seconds per set** (not reps). Each day can specify multiple sets of the same or different durations. The test day uses `[0]` as a sentinel — a single set where `targetSeconds == 0` means "hold as long as you can".

```json
{
  "id": "plank",
  "name": "Plank",
  "muscleGroup": "core_stability",
  "color": "#5B8A72",
  "countingMode": "timed",
  "defaultRestSeconds": 90,
  "levels": [
    {
      "level": 1,
      "variationName": "Forearm Plank",
      "restDayPattern": [2, 2, 3],
      "testTarget": 60,
      "totalDays": 10,
      "days": [
        {"day": 1, "sets": [20, 20, 20]},
        {"day": 2, "sets": [23, 23, 23]},
        {"day": 3, "sets": [26, 26, 26]},
        {"day": 4, "sets": [29, 29, 29]},
        {"day": 5, "sets": [32, 32, 32]},
        {"day": 6, "sets": [36, 36, 36]},
        {"day": 7, "sets": [40, 40, 40]},
        {"day": 8, "sets": [45, 45, 45]},
        {"day": 9, "sets": [52, 52, 52]},
        {"day": 10, "sets": [0]}
      ]
    },
    {
      "level": 2,
      "variationName": "Extended Plank",
      "restDayPattern": [2, 2, 3],
      "testTarget": 90,
      "totalDays": 10,
      "days": [
        {"day": 1, "sets": [25, 25, 25]},
        {"day": 2, "sets": [30, 30, 30]},
        {"day": 3, "sets": [35, 35, 35]},
        {"day": 4, "sets": [40, 40, 40]},
        {"day": 5, "sets": [45, 45, 45]},
        {"day": 6, "sets": [52, 52, 52]},
        {"day": 7, "sets": [60, 60, 60]},
        {"day": 8, "sets": [68, 68, 68]},
        {"day": 9, "sets": [78, 78, 78]},
        {"day": 10, "sets": [0]}
      ]
    },
    {
      "level": 3,
      "variationName": "Feet-Elevated Plank",
      "restDayPattern": [2, 2, 3],
      "testTarget": 120,
      "totalDays": 10,
      "days": [
        {"day": 1, "sets": [35, 35, 35]},
        {"day": 2, "sets": [40, 40, 40]},
        {"day": 3, "sets": [47, 47, 47]},
        {"day": 4, "sets": [54, 54, 54]},
        {"day": 5, "sets": [62, 62, 62]},
        {"day": 6, "sets": [72, 72, 72]},
        {"day": 7, "sets": [83, 83, 83]},
        {"day": 8, "sets": [95, 95, 95]},
        {"day": 9, "sets": [108, 108, 108]},
        {"day": 10, "sets": [0]}
      ]
    }
  ]
}
```

> **Test day sentinel:** `"sets": [0]` = 1 set, target 0 seconds. `TimedSetView(targetSeconds: 0)` enters count-up mode (hold as long as you can). The `testTarget` field (e.g. 60) is used for pass/fail only — if the held duration ≥ testTarget, the level advances.

- [ ] **Step 5: Add `rows` exercise**

```json
{
  "id": "rows",
  "name": "Rows",
  "muscleGroup": "upper_pull",
  "color": "#3A7CA5",
  "countingMode": "post_set_confirmation",
  "defaultRestSeconds": 90,
  "levels": [
    {
      "level": 1,
      "variationName": "Table Row",
      "restDayPattern": [2, 2, 3],
      "testTarget": 20,
      "totalDays": 10,
      "days": [
        {"day": 1, "sets": [3, 4, 4, 3, 2]},
        {"day": 2, "sets": [4, 4, 4, 3, 2]},
        {"day": 3, "sets": [4, 5, 4, 4, 3]},
        {"day": 4, "sets": [5, 5, 5, 4, 3]},
        {"day": 5, "sets": [6, 5, 5, 4, 4]},
        {"day": 6, "sets": [7, 6, 5, 5, 4]},
        {"day": 7, "sets": [8, 6, 6, 5, 4]},
        {"day": 8, "sets": [9, 7, 6, 6, 5]},
        {"day": 9, "sets": [10, 8, 8, 6, 5]},
        {"day": 10, "sets": []}
      ]
    },
    {
      "level": 2,
      "variationName": "Australian Row",
      "restDayPattern": [2, 2, 3],
      "testTarget": 20,
      "totalDays": 10,
      "days": [
        {"day": 1, "sets": [4, 5, 4, 4, 3]},
        {"day": 2, "sets": [5, 5, 5, 4, 3]},
        {"day": 3, "sets": [6, 5, 5, 5, 4]},
        {"day": 4, "sets": [7, 6, 5, 5, 4]},
        {"day": 5, "sets": [8, 6, 6, 5, 5]},
        {"day": 6, "sets": [9, 7, 6, 6, 5]},
        {"day": 7, "sets": [10, 8, 7, 6, 6]},
        {"day": 8, "sets": [11, 9, 8, 7, 6]},
        {"day": 9, "sets": [13, 10, 8, 8, 7]},
        {"day": 10, "sets": []}
      ]
    },
    {
      "level": 3,
      "variationName": "Archer Row",
      "restDayPattern": [2, 2, 3],
      "testTarget": 15,
      "totalDays": 10,
      "days": [
        {"day": 1, "sets": [3, 3, 3, 3, 3]},
        {"day": 2, "sets": [4, 3, 3, 3, 3]},
        {"day": 3, "sets": [4, 4, 4, 3, 3]},
        {"day": 4, "sets": [5, 4, 4, 4, 3]},
        {"day": 5, "sets": [5, 5, 5, 4, 3]},
        {"day": 6, "sets": [6, 5, 5, 5, 4]},
        {"day": 7, "sets": [7, 6, 5, 5, 4]},
        {"day": 8, "sets": [8, 6, 6, 5, 5]},
        {"day": 9, "sets": [9, 8, 6, 6, 5]},
        {"day": 10, "sets": []}
      ]
    }
  ]
}
```

- [ ] **Step 6: Add `dips` exercise**

```json
{
  "id": "dips",
  "name": "Dips",
  "muscleGroup": "upper_push",
  "color": "#C2553F",
  "countingMode": "post_set_confirmation",
  "defaultRestSeconds": 90,
  "levels": [
    {
      "level": 1,
      "variationName": "Bench Dip",
      "restDayPattern": [2, 2, 3],
      "testTarget": 20,
      "totalDays": 10,
      "days": [
        {"day": 1, "sets": [5, 6, 5, 5, 4]},
        {"day": 2, "sets": [6, 6, 5, 5, 4]},
        {"day": 3, "sets": [7, 6, 6, 5, 5]},
        {"day": 4, "sets": [8, 7, 6, 6, 5]},
        {"day": 5, "sets": [9, 8, 7, 6, 5]},
        {"day": 6, "sets": [10, 8, 8, 7, 6]},
        {"day": 7, "sets": [11, 10, 8, 8, 7]},
        {"day": 8, "sets": [12, 10, 10, 8, 8]},
        {"day": 9, "sets": [14, 12, 10, 10, 8]},
        {"day": 10, "sets": []}
      ]
    },
    {
      "level": 2,
      "variationName": "Chair Dip",
      "restDayPattern": [2, 2, 3],
      "testTarget": 20,
      "totalDays": 10,
      "days": [
        {"day": 1, "sets": [4, 5, 4, 4, 3]},
        {"day": 2, "sets": [5, 5, 4, 4, 3]},
        {"day": 3, "sets": [6, 5, 5, 5, 4]},
        {"day": 4, "sets": [7, 6, 5, 5, 4]},
        {"day": 5, "sets": [8, 7, 6, 5, 5]},
        {"day": 6, "sets": [9, 7, 7, 6, 5]},
        {"day": 7, "sets": [10, 8, 7, 7, 6]},
        {"day": 8, "sets": [11, 9, 8, 7, 6]},
        {"day": 9, "sets": [12, 10, 9, 8, 7]},
        {"day": 10, "sets": []}
      ]
    },
    {
      "level": 3,
      "variationName": "Parallel Bar Dip",
      "restDayPattern": [2, 2, 3],
      "testTarget": 15,
      "totalDays": 10,
      "days": [
        {"day": 1, "sets": [3, 3, 3, 3, 2]},
        {"day": 2, "sets": [4, 3, 3, 3, 3]},
        {"day": 3, "sets": [4, 4, 4, 3, 3]},
        {"day": 4, "sets": [5, 4, 4, 4, 3]},
        {"day": 5, "sets": [6, 5, 4, 4, 4]},
        {"day": 6, "sets": [6, 5, 5, 5, 4]},
        {"day": 7, "sets": [7, 6, 5, 5, 5]},
        {"day": 8, "sets": [8, 6, 6, 5, 5]},
        {"day": 9, "sets": [9, 8, 6, 6, 5]},
        {"day": 10, "sets": []}
      ]
    }
  ]
}
```

- [ ] **Step 7: Validate JSON is valid**

```bash
cat "inch/inch/Resources/exercise-data.json" | python3 -m json.tool > /dev/null && echo "Valid JSON" || echo "Invalid JSON"
```

Expected: `Valid JSON`

- [ ] **Step 8: Verify existing `ExerciseDataLoaderTests` still pass**

```bash
cd /Users/curtismartin/Work/inch-project && swift test --package-path Shared \
  --filter "ExerciseDataLoaderTests" 2>&1 | tail -20
```

- [ ] **Step 9: Commit**

```bash
git add inch/inch/Resources/exercise-data.json
git commit -m "feat: add hip_hinge, spinal_extension, plank, rows, dips; remove sit_ups"
```

---

## Chunk 3: Timed Workout UI (iOS)

### Task 6: Create `PreSetCountdownView`

**Files:**
- Create: `inch/inch/Features/Workout/PreSetCountdownView.swift`

This view shows a countdown (3…2…1…Go!) before a timed hold begins. Duration comes from `UserSettings.timedPrepCountdownSeconds` (default 5). After countdown completes, calls `onStart`.

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

struct PreSetCountdownView: View {
    let countdownSeconds: Int
    let holdDurationSeconds: Int  // 0 = test (unlimited); show "Hold as long as you can"
    let onStart: () -> Void

    @State private var remaining: Int

    init(countdownSeconds: Int, holdDurationSeconds: Int, onStart: @escaping () -> Void) {
        self.countdownSeconds = countdownSeconds
        self.holdDurationSeconds = holdDurationSeconds
        self.onStart = onStart
        _remaining = State(initialValue: countdownSeconds)
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("Get ready")
                .font(.title2)
                .foregroundStyle(.secondary)

            if holdDurationSeconds > 0 {
                Text("Hold for \(holdDurationSeconds)s")
                    .font(.headline)
            } else {
                Text("Hold as long as you can")
                    .font(.headline)
            }

            ZStack {
                Circle()
                    .stroke(.secondary.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: countdownSeconds > 0 ? Double(remaining) / Double(countdownSeconds) : 0)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: remaining)

                Text(remaining > 0 ? "\(remaining)" : "Go!")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .frame(width: 200, height: 200)

            Spacer()
        }
        .padding()
        .task {
            let endDate = Date.now.addingTimeInterval(Double(countdownSeconds))
            while remaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                remaining = max(0, Int(endDate.timeIntervalSinceNow.rounded(.up)))
            }
            onStart()
        }
        .onChange(of: remaining) { _, newValue in
            if newValue > 0 && newValue <= 3 {
                WorkoutSounds.playCountdownTick()
            } else if newValue == 0 {
                WorkoutSounds.playGo()
            }
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: remaining) { _, new in
            new > 0 && new <= 3
        }
        .sensoryFeedback(.success, trigger: remaining) { _, new in
            new == 0
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add inch/inch/Features/Workout/PreSetCountdownView.swift
git commit -m "feat: PreSetCountdownView for timed exercise prep countdown"
```

---

### Task 7: Create `TimedSetView`

**Files:**
- Create: `inch/inch/Features/Workout/TimedSetView.swift`

This view is shown during the actual timed hold. For prescribed holds (non-test days), it counts down from `targetSeconds`. For test days (`targetSeconds == 0`), it counts up (elapsed timer) and shows a "Stop" button. Calls `onComplete(actualDuration: Double)`.

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

struct TimedSetView: View {
    let targetSeconds: Int   // 0 = test day (count up)
    let onComplete: (_ actualDuration: Double) -> Void

    @State private var elapsed: Double = 0
    @State private var isComplete: Bool = false

    private var isTestDay: Bool { targetSeconds == 0 }

    private var progress: Double {
        isTestDay ? 0 : (targetSeconds > 0 ? min(elapsed / Double(targetSeconds), 1) : 0)
    }

    private var displaySeconds: Int {
        isTestDay ? Int(elapsed) : max(0, targetSeconds - Int(elapsed))
    }

    private var ringColor: Color {
        isComplete ? .green : .accentColor
    }

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(.secondary.opacity(0.2), lineWidth: 8)
                if isTestDay {
                    // Count up — show elapsed arc growing
                    Circle()
                        .trim(from: 0, to: min(elapsed / 120.0, 1))  // scale to 2min for visual
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                } else {
                    // Count down — show remaining arc shrinking
                    Circle()
                        .trim(from: 0, to: 1 - progress)
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }

                VStack(spacing: 2) {
                    Text(timeText(displaySeconds))
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(isTestDay ? "elapsed" : "remaining")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 200, height: 200)
            .animation(.linear(duration: 0.1), value: elapsed)

            if isComplete && !isTestDay {
                Text("Hold complete!")
                    .font(.subheadline)
                    .foregroundStyle(.green)
                    .transition(.opacity.combined(with: .scale))
            } else if isTestDay {
                Text("Hold as long as you can")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("target: \(targetSeconds)s")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button("Stop") {
                finish()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isComplete)
        }
        .animation(.easeInOut(duration: 0.3), value: isComplete)
        .task {
            let startDate = Date.now
            while !isComplete {
                try? await Task.sleep(for: .milliseconds(100))
                elapsed = Date.now.timeIntervalSince(startDate)
                if !isTestDay && elapsed >= Double(targetSeconds) && !isComplete {
                    isComplete = true
                    WorkoutSounds.playGo()
                    // Small delay so user sees "Hold complete!" before auto-finishing
                    try? await Task.sleep(for: .seconds(0.8))
                    finish()
                }
            }
        }
    }

    private func finish() {
        isComplete = true
        onComplete(elapsed)
    }

    private func timeText(_ seconds: Int) -> String {
        if seconds >= 60 {
            return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
        } else {
            return "\(seconds)s"
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add inch/inch/Features/Workout/TimedSetView.swift
git commit -m "feat: TimedSetView for active hold countdown/elapsed timer"
```

---

### Task 8: Update `WorkoutPhase` and `WorkoutViewModel` for timed mode

**Files:**
- Modify: `inch/inch/Features/Workout/WorkoutViewModel.swift`

We need two new phases: `.preparingTimedSet(targetSeconds: Int)` (showing the countdown) and `.inTimedSet(targetSeconds: Int, startedAt: Date)`. The existing `.inSet(startedAt:)` and `.confirming` phases are for post-set-confirmation mode only.

- [ ] **Step 1: Add new phases to `WorkoutPhase`**

```swift
enum WorkoutPhase: Equatable {
    case loading
    case ready
    case preparingTimedSet(targetSeconds: Int)  // NEW: pre-set countdown
    case inTimedSet(targetSeconds: Int)          // NEW: active hold (view owns elapsed timer)
    case inSet(startedAt: Date)
    case confirming(targetReps: Int, duration: Double)
    case resting(restSeconds: Int)
    case complete
}
```

- [ ] **Step 2: Add `startTimedSet()` and `completeTimedSet(actualDuration:)` methods**

After `startSet()` and `endSet()`, add:

```swift
func startTimedSet() {
    // currentTargetReps returns the sets[currentSetIndex] value.
    // For timed exercises, this IS the target seconds.
    phase = .preparingTimedSet(targetSeconds: currentTargetReps)
}

func countdownComplete() {
    guard case .preparingTimedSet(let target) = phase else { return }
    // Remove startedAt — the view manages its own elapsed timer
    phase = .inTimedSet(targetSeconds: target)
}

func completeTimedSet(actualDuration: Double, context: ModelContext, recordingURL: URL? = nil, phoneOrientation: String = "") {
    guard case .inTimedSet(let target) = phase else { return }
    saveTimedSet(targetDuration: target, actualDuration: actualDuration, context: context, recordingURL: recordingURL, phoneOrientation: phoneOrientation)
    advanceAfterSet(context: context)
}
```

- [ ] **Step 3: Add `saveTimedSet` method**

Add alongside `saveSet`:

```swift
private func saveTimedSet(targetDuration: Int, actualDuration: Double, context: ModelContext, recordingURL: URL? = nil, phoneOrientation: String = "") {
    guard let enrolment, let prescription, let def = enrolment.exerciseDefinition else { return }

    let todayStart = Calendar.current.startOfDay(for: Date.now)
    let allSets = (try? context.fetch(FetchDescriptor<CompletedSet>())) ?? []
    let totalSetsToday = allSets.filter { $0.completedAt >= todayStart }.count

    let completedSet = CompletedSet(
        sessionDate: sessionDate,
        exerciseId: def.exerciseId,
        level: enrolment.currentLevel,
        dayNumber: enrolment.currentDay,
        setNumber: currentSetIndex + 1,
        targetReps: 0,                      // not applicable for timed sets
        actualReps: 0,                      // not applicable for timed sets
        isTest: prescription.isTest,
        countingMode: .timed,
        setDurationSeconds: actualDuration, // actual hold time (reuses existing field)
        targetDurationSeconds: targetDuration
    )
    completedSet.enrolment = enrolment
    context.insert(completedSet)

    if let recordingURL {
        let attrs = try? FileManager.default.attributesOfItem(atPath: recordingURL.path)
        let fileSize = (attrs?[.size] as? Int) ?? 0

        let recording = SensorRecording(
            device: .iPhone,
            exerciseId: def.exerciseId,
            level: enrolment.currentLevel,
            dayNumber: enrolment.currentDay,
            setNumber: currentSetIndex + 1,
            confirmedReps: 0,
            sampleRateHz: 100,
            durationSeconds: actualDuration,
            countingMode: CountingMode.timed.rawValue,
            filePath: recordingURL.path,
            fileSizeBytes: fileSize,
            deviceModel: DeviceInfo.hardwareIdentifier,
            osVersion: DeviceInfo.osVersion,
            phonePlacement: Self.phonePlacement(for: def.exerciseId),
            phoneOrientation: phoneOrientation,
            totalSetsCompletedToday: totalSetsToday
        )
        recording.completedSet = completedSet
        context.insert(recording)
    }

    sessionTotalReps += 0  // timed sets contribute 0 reps
    try? context.save()
}
```

- [ ] **Step 4: Add `isTimedExercise` computed property**

Add alongside `currentTargetReps`:

```swift
var isTimedExercise: Bool { countingMode == .timed }
// For timed exercises, currentTargetReps returns the target seconds (e.g. 20).
// For rep exercises, currentTargetReps returns the target reps as before.
// No separate currentTargetDuration needed.
```

- [ ] **Step 5: Build to confirm no errors**

```bash
cd /Users/curtismartin/Work/inch-project && xcodebuild build \
  -scheme "inch" \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  -configuration Debug 2>&1 | grep -E "error:|BUILD" | tail -20
```

- [ ] **Step 6: Commit**

```bash
git add inch/inch/Features/Workout/WorkoutViewModel.swift
git commit -m "feat: WorkoutViewModel handles timed phases and saveTimedSet"
```

---

### Task 9: Update `WorkoutSessionView` to render timed phases

**Files:**
- Modify: `inch/inch/Features/Workout/WorkoutSessionView.swift`

- [ ] **Step 1: Add new cases to the phase switch in `body`**

In the `Group { switch viewModel.phase { ... } }` block, add after `.ready`:

```swift
case .preparingTimedSet(let targetSeconds):
    // Countdown before the hold begins. Note: sensor recording starts when
    // the hold begins (inTimedSet), NOT here — to avoid capturing countdown noise.
    PreSetCountdownView(
        countdownSeconds: settings?.timedPrepCountdownSeconds ?? 5,
        holdDurationSeconds: targetSeconds,
        onStart: {
            viewModel.countdownComplete()   // transitions to .inTimedSet
        }
    )

case .inTimedSet(let targetSeconds):
    TimedSetView(targetSeconds: targetSeconds) { actualDuration in
        let url = sensorConsented ? motionRecording.stopRecording() : nil
        if dualRecordingEnabled {
            let exerciseId = viewModel.enrolment?.exerciseDefinition?.exerciseId ?? ""
            watchConnectivity.sendRecordingStop(
                exerciseId: exerciseId,
                setNumber: viewModel.currentSetIndex + 1
            )
        }
        viewModel.completeTimedSet(
            actualDuration: actualDuration,
            context: modelContext,
            recordingURL: url,
            phoneOrientation: setStartOrientation
        )
    }
    .id(viewModel.currentSetIndex)
```

- [ ] **Step 2: Update `readyView` — show timed start button when appropriate**

In `readyView`, the existing code renders `RealTimeCountingView` for `.realTime` mode and a "Start Set" button for `.postSetConfirmation`. Add a third branch:

Replace the `} else {` block (which currently shows "Start Set" button):

```swift
} else if viewModel.countingMode == .timed {
    Button("Start Hold \(viewModel.currentSetIndex + 1)") {
        setStartOrientation = UIDevice.current.orientation.stringValue
        if sensorConsented {
            let exerciseId = viewModel.enrolment?.exerciseDefinition?.exerciseId ?? ""
            motionRecording.startRecording(
                exerciseId: exerciseId,
                setNumber: viewModel.currentSetIndex + 1,
                sessionId: sessionId,
                context: modelContext
            )
            if dualRecordingEnabled {
                watchConnectivity.sendRecordingStart(
                    exerciseId: exerciseId,
                    setNumber: viewModel.currentSetIndex + 1,
                    sessionId: sessionId
                )
            }
        }
        viewModel.startTimedSet()
    }
    .buttonStyle(.borderedProminent)
    .controlSize(.large)
} else {
    Button("Start Set \(viewModel.currentSetIndex + 1)") {
        // ... existing code unchanged
    }
}
```

- [ ] **Step 3: Update `shouldWarnOnBack` to handle timed phases**

```swift
private var shouldWarnOnBack: Bool {
    switch viewModel.phase {
    case .loading, .complete:
        false
    case .inSet, .preparingTimedSet, .inTimedSet:
        // Always warn if actively doing a set or counting down
        true
    default:
        viewModel.currentSetIndex > 0
    }
}
```

- [ ] **Step 4: Update `onChange(of: viewModel.phase)` to start recording on `.inTimedSet`**

The existing `onChange` handler starts recording on `.inSet`. Add a case for `.inTimedSet`:

```swift
case .inTimedSet:
    // Recording starts HERE (after countdown) — not during .preparingTimedSet
    showHoldPhoneHint = false
    if sensorConsented {
        let exerciseId = viewModel.enrolment?.exerciseDefinition?.exerciseId ?? ""
        motionRecording.startRecording(
            exerciseId: exerciseId,
            setNumber: viewModel.currentSetIndex + 1,
            sessionId: sessionId,
            context: modelContext
        )
        if dualRecordingEnabled {
            watchConnectivity.sendRecordingStart(
                exerciseId: exerciseId,
                setNumber: viewModel.currentSetIndex + 1,
                sessionId: sessionId
            )
        }
    }
```

Also verify the existing `.confirming` case (which stops recording) is NOT triggered for timed exercises — it won't be, since timed exercises go `.inTimedSet` → completeTimedSet callback (which manually stops recording) → `.resting` or `.complete`, skipping `.confirming` entirely.

- [ ] **Step 5: Update `RestTimerView` call site to show "Next: Xs hold" for timed**

```swift
case .resting(let seconds):
    RestTimerView(
        totalSeconds: seconds,
        nextSetReps: viewModel.isTimedExercise ? nil : viewModel.prescription?.sets[safe: viewModel.currentSetIndex],
        nextSetDuration: viewModel.isTimedExercise ? viewModel.currentTargetDuration : nil
    ) {
        viewModel.finishRest()
    }
```

> This requires `RestTimerView` to accept `nextSetDuration: Int?` — update that in the next step.

- [ ] **Step 6: Update `RestTimerView` to show hold duration**

Open `inch/inch/Features/Workout/RestTimerView.swift` and:
- Add `let nextSetDuration: Int?` parameter (default `nil`)
- Change "Next: N reps" to "Next: Ns hold" when `nextSetDuration != nil`

```swift
if let nextSetDuration {
    Text("Next: \(nextSetDuration)s hold")
        .font(.subheadline)
        .foregroundStyle(.secondary)
} else if let nextSetReps {
    Text("Next: \(nextSetReps) reps")
        .font(.subheadline)
        .foregroundStyle(.secondary)
}
```

- [ ] **Step 7: Build**

```bash
cd /Users/curtismartin/Work/inch-project && xcodebuild build \
  -scheme "inch" \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  -configuration Debug 2>&1 | grep -E "error:|BUILD" | tail -20
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 8: Commit**

```bash
git add \
  inch/inch/Features/Workout/WorkoutSessionView.swift \
  inch/inch/Features/Workout/RestTimerView.swift
git commit -m "feat: WorkoutSessionView renders timed hold phases; RestTimerView shows hold duration"
```

---

### Task 10: Timed test day UI

**Files:**
- Modify: `inch/inch/Features/Workout/TestDayView.swift`

Test days for timed exercises: user holds as long as possible. Test passes if they hold ≥ `testTarget` seconds.

- [ ] **Step 1: Add timed test detection to `TestDayView`**

Add `@State private var isTimed: Bool = false` state variable. Set it in `load()` by checking the exercise's `countingMode`:

```swift
private func load() {
    let enrolment: ExerciseEnrolment? = modelContext.registeredModel(for: enrolmentId)
        ?? fetchEnrolment()
    guard let enrolment else { return }
    self.enrolment = enrolment
    let levelDef = enrolment.exerciseDefinition?
        .levels?
        .first(where: { $0.level == enrolment.currentLevel })
    testTarget = levelDef?.testTarget ?? 0
    // isTimed: check the exercise's countingMode, not the DayPrescription
    isTimed = enrolment.exerciseDefinition?.countingMode == .timed
}
```

> **Why `countingMode` not `DayPrescription.isTimed`:** `DayPrescription` has no direct reference to its parent exercise. The `countingMode` on `ExerciseDefinition` is the authoritative source — all timed exercises have `countingMode == .timed`.

- [ ] **Step 2: Update `readyView` to show appropriate instructions**

```swift
private var readyView: some View {
    VStack(spacing: 32) {
        Spacer()

        VStack(spacing: 12) {
            Text("Test Day")
                .font(.largeTitle)
                .fontWeight(.bold)

            if isTimed {
                Text("Hold as long as you can.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Target to pass: \(testTarget)s")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.orange.opacity(0.12), in: Capsule())
                    .foregroundStyle(.orange)
            } else {
                Text("Do as many reps as you can.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Target to pass: \(testTarget)")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.orange.opacity(0.12), in: Capsule())
                    .foregroundStyle(.orange)
            }
        }

        Spacer()

        if isTimed {
            // Prep countdown then timed hold
            TimedSetView(targetSeconds: 0) { actualDuration in
                phase = .counting(reps: 0)
                finishTimedTest(duration: actualDuration)
            }
        } else {
            RealTimeCountingView(targetReps: testTarget, autoCompleteAtTarget: false) { actual, _ in
                phase = .counting(reps: actual)
                finishTest(reps: actual)
            }
        }
    }
    .padding()
}
```

- [ ] **Step 3: Add `finishTimedTest(duration:)` method**

```swift
private func finishTimedTest(duration: Double) {
    guard let enrolment,
          let def = enrolment.exerciseDefinition,
          let levelDef = def.levels?.first(where: { $0.level == enrolment.currentLevel })
    else { return }

    let passed = duration >= Double(testTarget)
    let sessionDate = Date.now

    let completedSet = CompletedSet(
        sessionDate: sessionDate,
        exerciseId: def.exerciseId,
        level: enrolment.currentLevel,
        dayNumber: enrolment.currentDay,
        setNumber: 1,
        targetReps: 0,
        actualReps: 0,
        isTest: true,
        testPassed: passed,
        countingMode: .timed,
        setDurationSeconds: duration,       // actual hold time
        targetDurationSeconds: testTarget   // prescribed target in seconds
    )
    completedSet.enrolment = enrolment
    modelContext.insert(completedSet)

    let snapshot = EnrolmentSnapshot(enrolment)
    let levelSnap = LevelSnapshot(levelDef)
    // For timed test, pass totalReps = 0 (not used for passing logic in timed mode)
    // The scheduler uses testTarget comparison — we pass the reps as duration-converted
    // NOTE: SchedulingEngine.applyCompletion uses totalReps >= testTarget to determine pass.
    // For timed tests, we pass Int(duration) as the "reps" so the existing logic works.
    let updated = scheduler.applyCompletion(
        to: snapshot,
        level: levelSnap,
        actualDate: sessionDate,
        totalReps: Int(duration)  // treat seconds as "reps" for the scheduler's pass check
    )
    let nextDate = scheduler.computeNextDate(enrolment: updated, level: levelSnap)
    scheduler.writeBack(updated, to: enrolment, nextDate: nextDate)
    try? modelContext.save()

    let repsForDisplay = Int(duration)
    phase = .result(reps: repsForDisplay, passed: passed, nextDate: nextDate)
}
```

- [ ] **Step 4: Update `TestPhase` enum and `resultView` to handle timed tests**

`TestPhase.result(reps: Int, passed: Bool, nextDate: Date?)` uses `reps` for both rep counts and seconds (for timed). This is fine — in `finishTimedTest`, we pass `Int(duration)` as "reps". The `resultView` already receives `reps: Int`.

Update `resultView` to use `isTimed` for display:

```swift
Text(isTimed ? "\(reps)s held — target was \(testTarget)s"
             : "\(reps) reps — target was \(testTarget)")
    .font(.subheadline)
    .foregroundStyle(.secondary)
```

> No enum change needed. `reps` carries seconds for timed tests — this is an acceptable semantic overload since `TestPhase` is private to the view.

- [ ] **Step 5: Build**

```bash
cd /Users/curtismartin/Work/inch-project && xcodebuild build \
  -scheme "inch" \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  -configuration Debug 2>&1 | grep -E "error:|BUILD" | tail -20
```

- [ ] **Step 6: Commit**

```bash
git add inch/inch/Features/Workout/TestDayView.swift
git commit -m "feat: TestDayView supports timed test mode"
```

---

### Task 11: Display variation name in workout UI

**Files:**
- Modify: `inch/inch/Features/Workout/WorkoutSessionView.swift` (minor addition)
- Modify: `inch/inch/Features/Workout/WorkoutViewModel.swift` (minor addition)

When an exercise has a `variationName` for the current level, show it prominently in the workout session header so users know which variation they're doing.

- [ ] **Step 1: Add `variationName` computed property to `WorkoutViewModel`**

```swift
var variationName: String? {
    enrolment?.exerciseDefinition?
        .levels?
        .first(where: { $0.level == (enrolment?.currentLevel ?? 0) })?
        .variationName
}
```

- [ ] **Step 2: Update `setProgressHeader` in `WorkoutSessionView`**

In the `VStack(alignment: .leading)` inside `setProgressHeader`, add variation name below the exercise name display:

```swift
VStack(alignment: .leading, spacing: 4) {
    Text("Set \(viewModel.currentSetIndex + 1) of \(viewModel.totalSets)")
        .font(.headline)
    if let variation = viewModel.variationName {
        Text(variation)
            .font(.caption)
            .foregroundStyle(Color(hex: viewModel.accentColorHex) ?? .accentColor)
    }
    Text("Day \(viewModel.enrolment?.currentDay ?? 0) · Level \(viewModel.enrolment?.currentLevel ?? 0)")
        .font(.caption)
        .foregroundStyle(.secondary)
}
```

> **Note:** `Color(hex:)` — check if this extension already exists in the project. Search for it:
> ```bash
> grep -r "Color(hex" /Users/curtismartin/Work/inch-project/inch --include="*.swift" | head -5
> ```
> If not, use `.accentColor` as fallback or add a simple extension.

- [ ] **Step 3: Build**

```bash
cd /Users/curtismartin/Work/inch-project && xcodebuild build \
  -scheme "inch" \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  -configuration Debug 2>&1 | grep -E "error:|BUILD" | tail -20
```

- [ ] **Step 4: Commit**

```bash
git add \
  inch/inch/Features/Workout/WorkoutViewModel.swift \
  inch/inch/Features/Workout/WorkoutSessionView.swift
git commit -m "feat: show variation name in workout header for multi-variation exercises"
```

---

## Chunk 4: Settings + Watch

### Task 12: Add "Timed Exercises" settings row

**Files:**
- Create: `inch/inch/Features/Settings/TimedExerciseSettingsView.swift`
- Modify: `inch/inch/Features/Settings/SettingsView.swift`

Users can configure the pre-set countdown duration (3s, 5s, 10s).

- [ ] **Step 1: Create `TimedExerciseSettingsView.swift`**

```swift
import SwiftUI
import InchShared

struct TimedExerciseSettingsView: View {
    @Bindable var settings: UserSettings
    @Environment(\.modelContext) private var modelContext

    private let options = [3, 5, 10]

    var body: some View {
        List {
            Section {
                Picker("Prep countdown", selection: $settings.timedPrepCountdownSeconds) {
                    ForEach(options, id: \.self) { seconds in
                        Text("\(seconds) seconds").tag(seconds)
                    }
                }
                .onChange(of: settings.timedPrepCountdownSeconds) {
                    try? modelContext.save()
                }
            } footer: {
                Text("Countdown shown before each timed hold so you can get into position.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Timed Exercises")
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

- [ ] **Step 2: Add the row to `SettingsView`**

In the `workoutSection`, add after "Counting Method":

```swift
if let settings = viewModel.settings {
    NavigationLink("Timed Exercises") {
        TimedExerciseSettingsView(settings: settings)
    }
}
```

- [ ] **Step 3: Build**

```bash
cd /Users/curtismartin/Work/inch-project && xcodebuild build \
  -scheme "inch" \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  -configuration Debug 2>&1 | grep -E "error:|BUILD" | tail -20
```

- [ ] **Step 4: Commit**

```bash
git add \
  inch/inch/Features/Settings/TimedExerciseSettingsView.swift \
  inch/inch/Features/Settings/SettingsView.swift
git commit -m "feat: Timed Exercises settings with configurable prep countdown"
```

---

### Task 13: Watch timed exercise support

**Files:**
- Create: `inch/inchwatch Watch App/Features/WatchTimedSetView.swift`
- Modify: `inch/inchwatch Watch App/Features/WatchWorkoutView.swift`
- Modify: `inch/inchwatch Watch App/Features/WatchWorkoutViewModel.swift`

- [ ] **Step 1: Create `WatchTimedSetView.swift`**

```swift
import SwiftUI
import WatchKit

struct WatchTimedSetView: View {
    let targetSeconds: Int   // 0 = test day
    let onComplete: (_ actualDuration: Double) -> Void

    @State private var elapsed: Double = 0
    @State private var isComplete: Bool = false

    private var isTestDay: Bool { targetSeconds == 0 }

    private var displaySeconds: Int {
        isTestDay ? Int(elapsed) : max(0, targetSeconds - Int(elapsed))
    }

    private var progress: Double {
        isTestDay ? 0 : (targetSeconds > 0 ? min(elapsed / Double(targetSeconds), 1) : 0)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(.secondary.opacity(0.2), lineWidth: 6)
                if !isTestDay {
                    Circle()
                        .trim(from: 0, to: 1 - progress)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }

                Text(timeText(displaySeconds))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(width: 100, height: 100)
            .animation(.linear(duration: 0.1), value: elapsed)

            Button("Stop") {
                finish()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isComplete)
        }
        .task {
            let startDate = Date.now
            while !isComplete {
                try? await Task.sleep(for: .milliseconds(100))
                elapsed = Date.now.timeIntervalSince(startDate)
                if !isTestDay && elapsed >= Double(targetSeconds) && !isComplete {
                    isComplete = true
                    WKInterfaceDevice.current().play(.success)
                    try? await Task.sleep(for: .seconds(0.8))
                    finish()
                }
            }
        }
    }

    private func finish() {
        isComplete = true
        onComplete(elapsed)
    }

    private func timeText(_ seconds: Int) -> String {
        seconds >= 60 ? "\(seconds / 60):\(String(format: "%02d", seconds % 60))" : "\(seconds)s"
    }
}
```

- [ ] **Step 2: Update `WatchWorkoutViewModel` to handle timed prescription**

Open `WatchWorkoutViewModel.swift`. Check how `phase` is set and how sets are advanced. Add:
- `var isTimed: Bool { session.countingMode == "timed" }`
- For timed sets, `targetReps` (= `session.sets[currentSet - 1]`) returns the target seconds — consistent with iPhone side.
- `endSetTimed(duration:)` method (see Step 3).

> The Watch view already switches on `session.countingMode == "real_time"`. Add a third branch for `"timed"`.
> **Note on `totalSets`**: `WatchWorkoutViewModel.totalSets = session.sets.count`. Since timed exercises use `sets: [Int]` with one entry per set (e.g. `[20, 20, 20]`), `totalSets` is correctly 3. Set advancement logic is unchanged.

- [ ] **Step 3: Update `WatchWorkoutView` to render `WatchTimedSetView`**

In the `.inSet` case:

```swift
case .inSet:
    if session.countingMode == "real_time" {
        WatchRealTimeCountingView(...)
    } else if session.countingMode == "timed" {
        WatchTimedSetView(
            targetSeconds: session.durationSeconds ?? 0
        ) { actualDuration in
            viewModel.endSetTimed(duration: actualDuration)
        }
    } else {
        WatchInSetView(...)
    }
```

Add `endSetTimed(duration: Double)` to `WatchWorkoutViewModel`:

```swift
func endSetTimed(duration: Double) {
    // Store duration for reporting, then advance
    // Similar to existing confirmSet — saves to history and moves to rest
    totalReps += 0  // no reps for timed
    advanceSet()
}
```

> **Note:** The Watch sends a `WatchCompletionReport` with `WatchSetResult` objects. Currently `WatchSetResult` has `actualReps`. For timed sets, pass `actualReps: 0` and `durationSeconds: actualDuration`. Check that `WatchSetResult` already has `durationSeconds: Double?` — it was defined in the spec. If not, add it.

- [ ] **Step 4: Build the watch target**

```bash
cd /Users/curtismartin/Work/inch-project && xcodebuild build \
  -scheme "inchwatch Watch App" \
  -destination "platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)" \
  -configuration Debug 2>&1 | grep -E "error:|BUILD" | tail -20
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: Commit**

```bash
git add \
  "inch/inchwatch Watch App/Features/WatchTimedSetView.swift" \
  "inch/inchwatch Watch App/Features/WatchWorkoutView.swift" \
  "inch/inchwatch Watch App/Features/WatchWorkoutViewModel.swift"
git commit -m "feat: Watch supports timed exercise holds"
```

---

## Chunk 5: History & Program UI Updates

### Task 14: Show variation name and timed duration in history

**Files:**
- Modify: `inch/inch/Features/History/HistoryViewModel.swift`

The history currently shows reps per set. For timed sets (`actualDurationSeconds != nil`), show "Xs" instead of "N reps".

- [ ] **Step 1: Check `HistoryViewModel` and history display**

```bash
cat /Users/curtismartin/Work/inch-project/inch/inch/Features/History/HistoryViewModel.swift
```

Find where `actualReps` is displayed. If it's in a view file, update the view. If computed in the view model, add a helper.

- [ ] **Step 2: Update any display of `actualReps` to check `setDurationSeconds` for timed sets**

In the relevant view or view model, where sets are displayed:

```swift
// For timed sets: show "Xs hold" instead of "0 reps"
if set.countingMode == .timed, let duration = set.setDurationSeconds {
    Text(String(format: "%.0fs hold", duration))
} else {
    Text("\(set.actualReps) reps")
}
```

Also: where "target N reps" is shown as a secondary line (when actual differs from target), suppress it for timed sets (`set.countingMode == .timed`). The target for timed sets comes from `set.targetDurationSeconds`, not `set.targetReps` (which is 0).

- [ ] **Step 3: Build**

```bash
cd /Users/curtismartin/Work/inch-project && xcodebuild build \
  -scheme "inch" \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  -configuration Debug 2>&1 | grep -E "error:|BUILD" | tail -20
```

- [ ] **Step 4: Commit**

```bash
git add inch/inch/Features/History/HistoryViewModel.swift
git commit -m "feat: history shows hold duration for timed sets"
```

---

### Task 15: Show variation name in program/exercise detail

**Files:**
- Modify: relevant Program view files (check `ProgramView.swift` / `ExerciseDetailView.swift`)

When an exercise has level variation names, show them in the program view.

- [ ] **Step 1: Find program views**

```bash
ls /Users/curtismartin/Work/inch-project/inch/inch/Features/Program/
```

- [ ] **Step 2: In the level progression display, add variation name**

Where `LevelDefinition` is displayed, add variation name as subtitle when present:

```swift
VStack(alignment: .leading) {
    Text("Level \(level.level)")
        .font(.headline)
    if let variation = level.variationName {
        Text(variation)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
```

- [ ] **Step 3: Update any day/set summary rows to handle timed days**

Find where `DayPrescription.sets` is summarised (e.g. "5 sets · 34 reps"). For timed exercises, show "3 sets · 20s" instead of rep totals. Check for something like `setSummary(day.sets)` or `"\(day.setCount) sets · \(day.totalReps) reps"`.

For timed exercises, guard on the exercise's `countingMode`:

```swift
// In the parent view that has access to the exercise definition:
if exercise.countingMode == .timed {
    // e.g. day.sets = [20, 20, 20]
    let targetSeconds = day.sets.first ?? 0
    Text("\(day.sets.count) sets · \(targetSeconds)s hold")
} else {
    Text("\(day.sets.count) sets · \(day.totalReps) reps")
}
```

> **Note:** For test days (`day.isTest`), `sets = [0]` for timed. Show "Test — hold as long as you can" instead of "1 sets · 0s hold".

- [ ] **Step 4: Build and commit**

```bash
cd /Users/curtismartin/Work/inch-project && xcodebuild build \
  -scheme "inch" \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  -configuration Debug 2>&1 | grep -E "error:|BUILD" | tail -20
git add inch/inch/Features/Program/
git commit -m "feat: program view shows variation name per level and timed set summaries"
```

---

## Chunk 6: Final Integration + Migration Verification

### Task 16: Update `sit_ups` references throughout codebase ✅ COMPLETED

**Files:**
- Modify: `Shared/Sources/InchShared/Engine/RepCounter.swift` (if sit_ups config exists)
- Modify: `inch/inch/Features/Workout/WorkoutSessionView.swift` (phoneAutoCountedExercises)
- Modify: `inch/inchwatch Watch App/Features/WatchWorkoutView.swift` (watchAutoCountedExercises)
- Modify: `inch/inch/Services/WatchConnectivityService.swift` (if sit_ups hardcoded)

- [x] **Step 1: Find all `sit_ups` string references**

```bash
grep -r "sit_ups" /Users/curtismartin/Work/inch-project --include="*.swift" | grep -v ".git" | grep -v "Tests"
```

- [x] **Step 2: Update `phoneAutoCountedExercises` in `WorkoutSessionView`**

Line 48–51 of `WorkoutSessionView.swift`:

```swift
private static let phoneAutoCountedExercises: Set<String> = [
    "push_ups", "pull_ups", "squats", "hip_hinge", "dead_bugs"
    // "sit_ups" removed (retired); "glute_bridges" renamed to "hip_hinge"
]
```

- [x] **Step 3: Update `phoneHint` in `WorkoutSessionView` (line 27)**

```swift
private var phoneHint: (message: String, icon: String)? {
    switch exerciseId {
    case "sit_ups", "dead_bugs", "squats":
        // sit_ups still kept here for any historical sessions, plus dead_bugs and squats
        return ("Hold your phone for better tracking", "hand.raised.fill")
    case "pull_ups", "push_ups", "hip_hinge":
        // "glute_bridges" → "hip_hinge"
        return ("Put your phone in your pocket for better tracking", "iphone")
    default:
        return nil
    }
}
```

- [x] **Step 4: Remove `sit_ups` from watch auto-counted exercises in `WatchWorkoutView.swift` (line 25)**

```swift
private static let watchAutoCountedExercises: Set<String> = ["dead_bugs"]
// "sit_ups" removed (retired); dead_bugs is the replacement
```

- [x] **Step 5: Update `RepCountingConfig` for `hip_hinge`**

```bash
grep -r "glute_bridges\|sit_ups" /Users/curtismartin/Work/inch-project/Shared --include="*.swift"
```

In `RepCounter.swift` or `RepCountingConfig.swift`, update:
- `"glute_bridges"` → `"hip_hinge"` (keep the same config values — same movement pattern)
- Remove `"sit_ups"` config entry (exercise retired)

- [x] **Step 6: Update `DataUploadService.validExerciseIds`**

In `inch/inch/Services/DataUploadService.swift`:

```swift
private static let validExerciseIds: Set<String> = [
    "push_ups", "squats", "dead_bugs", "pull_ups", "hip_hinge",
    "spinal_extension", "plank", "rows", "dips"
    // "sit_ups" removed (retired); "glute_bridges" → "hip_hinge"
]
```

- [x] **Step 7: Update `WorkoutViewModel.phonePlacement` (line 80-85)**

```swift
private static func phonePlacement(for exerciseId: String) -> String {
    switch exerciseId {
    case "sit_ups", "dead_bugs", "squats": return "hand"
    case "push_ups", "pull_ups", "hip_hinge", "dips", "rows": return "pocket"
    default: return ""
    }
}
```

- [x] **Step 8: Build the full project (iOS + Watch)**

```bash
cd /Users/curtismartin/Work/inch-project && xcodebuild build \
  -scheme "inch" \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  -configuration Debug 2>&1 | grep -E "error:|BUILD" | tail -20
```

- [x] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: update exercise ID references; sit_ups retired; glute_bridges→hip_hinge"
```

---

### Task 17: Schema migration verification ✅ COMPLETED

**Files:**
- No code changes — this task verifies migration works on a device with v1 data.

- [x] **Step 1: Run the app in simulator (fresh install)**

In Xcode, build and run on iPhone 16 Pro simulator. Verify onboarding completes, exercises load, workout can be started.

- [x] **Step 2: Verify migration from v1 (simulate existing user)**

To test migration without wiping:
1. Install old build on simulator → run through onboarding → complete one workout
2. Archive + install new build over it
3. Verify the app launches without crashing
4. Verify existing completed sets are preserved
5. Verify new exercises appear in enrolment view

> **Why lightweight migration works:** All new fields (`variationName`, `durationSeconds`, `targetDurationSeconds`, `actualDurationSeconds`, `timedPrepCountdownSeconds`) have Swift defaults or are `Optional`. SwiftData's lightweight migration adds the columns with NULL/default values for existing rows. No data is lost.

- [x] **Step 3: Test timed workout end-to-end**

1. Enrol in Plank (L1)
2. Start workout → ReadyView shows "Start Hold 1"
3. Tap Start → PreSetCountdownView shows 5s countdown
4. After countdown → TimedSetView shows hold with countdown ring
5. Ring completes at 20s → "Hold complete!" → auto-finishes
6. Rest timer appears showing "Next: 20s hold"
7. After all sets → ExerciseCompleteView
8. Navigate to History → shows "20s hold" not "0 reps"

- [x] **Step 4: Test rep-based exercises still work unchanged**

Start a Push-Up workout → verify flow unchanged.

- [x] **Step 5: Final commit**

```bash
git add -A
git commit -m "chore: timed exercises and exercise expansion — integration verified"
```

---

## Testing Summary

All tests use Swift Testing. Run with:
```bash
cd /Users/curtismartin/Work/inch-project && swift test --package-path Shared 2>&1 | tail -30
```

Key tests to write (covered in Tasks 3, 8, 10):
- `ExerciseDataLoaderTests` — parsing `variationName`, `durationSeconds` from JSON
- `WorkoutViewModelTests` — verify `saveTimedSet` creates `CompletedSet` with correct duration fields
- `DayPrescriptionTests` — `isTimed` returns correct value

---

## Known Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| V1→V2 migration crashes on first launch | Only one new field added to schema (`variationName` and `targetDurationSeconds`), both optional; `ModelContainerFactory` updated to pass `migrationPlan:`; lightweight migration handles automatically |
| `sit_ups` referenced in existing `SensorRecording` data | Old sit_ups recordings have `uploadStatus == .uploaded` or will be skipped by `validExerciseIds` guard; no data loss |
| Scheduler uses `totalReps >= testTarget` for test pass — timed tests pass `Int(duration)` | Acceptable; both are Int comparisons; timed test target (e.g. 60) compares with Int(seconds held); semantics clear from context |
| `plank` timed test day has `sets: [0]` | `TimedSetView(targetSeconds: 0)` enters count-up (elapsed) mode — intended behaviour |
| `DayPrescription.totalReps` returns sum of seconds for timed days | History/stats guard on `countingMode == .timed` before displaying totalReps as "reps" |
| Watch doesn't have `timedPrepCountdownSeconds` from UserSettings | Watch omits prep countdown; user starts hold directly — acceptable given Watch's quick-glance UX |

---

## Summary of New Files

```
Shared/Sources/InchShared/Models/BodyweightSchemaV2.swift  → included in updated BodyweightSchema.swift
inch/inch/Features/Workout/PreSetCountdownView.swift
inch/inch/Features/Workout/TimedSetView.swift
inch/inch/Features/Settings/TimedExerciseSettingsView.swift
inch/inchwatch Watch App/Features/WatchTimedSetView.swift
```

## Summary of New Exercise IDs

| ID | Name | Muscle Group | Mode |
|----|------|-------------|------|
| `hip_hinge` | Hip Hinge | lower_posterior | post_set_confirmation |
| `spinal_extension` | Spinal Extension | lower_posterior | post_set_confirmation |
| `plank` | Plank | core_stability | timed |
| `rows` | Rows | upper_pull | post_set_confirmation |
| `dips` | Dips | upper_push | post_set_confirmation |
| ~~`sit_ups`~~ | ~~Sit-Ups~~ | retired | — |
| ~~`glute_bridges`~~ | renamed to `hip_hinge` | — | — |
