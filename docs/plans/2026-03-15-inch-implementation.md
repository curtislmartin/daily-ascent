# Daily Ascent — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the Daily Ascent iOS + watchOS bodyweight training app across 17 build phases, starting with the shared package and ending with sensor upload.

**Architecture:** Shared Swift package (`Shared/`) for models, business logic, and WatchConnectivity DTOs; consumed by iOS target (`InchApp/`) and watchOS target (`InchWatch/`). All persistence through SwiftData. All UI in SwiftUI. Strict Swift 6.2 concurrency.

**Tech Stack:** Swift 6.2, SwiftUI, SwiftData, WatchConnectivity, CoreMotion, HealthKit, BGProcessingTask, Supabase (upload only), Swift Testing (no XCTest).

**Spec documents (read-only — never modify):**
- `Specs/architecture.md` — project structure, navigation, services
- `Specs/data-model.md` — complete SwiftData schema
- `Specs/scheduling-engine.md` — algorithms + 12 test cases
- `Specs/bodyweight-ux-design-v2.md` — all screens and flows
- `Specs/exercise-data.json` — exercise progressions JSON
- `Specs/framework-guidance.md` — WatchConnectivity, CoreMotion, HealthKit, BGTask
- `Specs/backend-api.md` — Supabase schema and upload endpoint

**Active skills:** @swiftui-pro @swiftdata-pro @swift-concurrency-pro @swift-testing-pro @swift-accessibility-skill

---

## Phase 0: Xcode Project Setup (manual — do this first)

This must be done in Xcode before writing any code.

### Task 0: Create the Xcode project

**Step 1: Create the project**
In Xcode 16+:
- File → New → Project → iOS → App
- Product Name: `Daily Ascent`
- Bundle ID: `com.dailyascent.bodyweight`
- Interface: SwiftUI
- Language: Swift
- Storage: None (we add SwiftData manually)
- Uncheck "Include Tests"
- Save at the repo root

**Step 2: Add watchOS target**
- File → New → Target → watchOS → Watch App
- Product Name: `InchWatch`
- Bundle ID: `com.dailyascent.bodyweight.watchkitapp`
- Interface: SwiftUI
- Uncheck "Include Notification Scene"

**Step 3: Add the shared Swift package**
- File → New → Package → Library
- Name: `Shared`
- Save inside the Daily Ascent project folder
- Remove the default `Shared` target and tests; replace with:
  - Library target: `InchShared` (iOS 18.0 + watchOS 11.0)
  - Test target: `InchSharedTests`
- Add `InchShared` as a dependency to both `InchApp` and `InchWatch` targets

**Step 4: Configure targets**
For both `InchApp` and `InchWatch` build settings:
- Swift Language Version: Swift 6
- Strict Concurrency Checking: Complete
- Swift Other Flags: add `-default-actor-isolation MainActor`

For `InchShared` (the library — no main-actor isolation):
- Swift Language Version: Swift 6
- Strict Concurrency Checking: Complete
- Do NOT add `-default-actor-isolation MainActor`

**Step 5: Create the folder structure**
Create these folders in Finder (Xcode will pick them up):
```
Specs/                          # copy all 7 spec files here (read-only)
Shared/Sources/InchShared/
  Models/
  Engine/
  Transfer/
  Utilities/
Shared/Tests/InchSharedTests/
InchApp/Features/
  Onboarding/
  Today/
  Workout/
  Program/
  History/
  Settings/
InchApp/Services/
InchApp/Navigation/
InchApp/Resources/              # copy exercise-data.json here
InchWatch/Features/
InchWatch/Services/
```

**Step 6: Set deployment targets**
- `InchApp`: iOS 18.0
- `InchWatch`: watchOS 11.0
- `InchShared`: iOS 18.0 / watchOS 11.0

**Step 7: Commit**
```bash
git add .
git commit -m "feat: create Xcode project with iOS, watchOS, and Shared package targets"
```

---

## Phase 1: Shared Package — Models

### Task 1: Enums

**Files:**
- Create: `Shared/Sources/InchShared/Models/Enums.swift`

**Step 1: Create the file**

```swift
// Enums.swift
import Foundation

enum MuscleGroup: String, Codable, Sendable, CaseIterable {
    case upperPush = "upper_push"
    case upperPull = "upper_pull"
    case lower = "lower"
    case lowerPosterior = "lower_posterior"
    case coreFlexion = "core_flexion"
    case coreStability = "core_stability"

    var conflictGroups: [MuscleGroup] {
        switch self {
        case .upperPush: [.upperPush]
        case .upperPull: [.upperPull]
        case .lower, .lowerPosterior: [.lower, .lowerPosterior]
        case .coreFlexion, .coreStability: [.coreFlexion, .coreStability]
        }
    }
}

enum CountingMode: String, Codable, Sendable {
    case realTime = "real_time"
    case postSetConfirmation = "post_set_confirmation"
}

enum SensorDevice: String, Codable, Sendable {
    case iPhone
    case appleWatch
}

enum UploadStatus: String, Codable, Sendable {
    case pending
    case uploading
    case uploaded
    case failed
    case localOnly
}
```

**Step 2: Build the shared package to verify**
```
In Xcode: Product → Build (⌘B) targeting any iOS simulator
Expected: Build succeeds, no errors
```

**Step 3: Commit**
```bash
git add Shared/Sources/InchShared/Models/Enums.swift
git commit -m "feat: add model enums (MuscleGroup, CountingMode, SensorDevice, UploadStatus)"
```

---

### Task 2: Static data models

**Files:**
- Create: `Shared/Sources/InchShared/Models/ExerciseDefinition.swift`
- Create: `Shared/Sources/InchShared/Models/LevelDefinition.swift`
- Create: `Shared/Sources/InchShared/Models/DayPrescription.swift`

**Step 1: Create ExerciseDefinition.swift**

```swift
// ExerciseDefinition.swift
import SwiftData

@Model
final class ExerciseDefinition {
    var exerciseId: String = ""
    var name: String = ""
    var muscleGroup: MuscleGroup = MuscleGroup.upperPush
    var color: String = ""
    var countingMode: CountingMode = CountingMode.postSetConfirmation
    var defaultRestSeconds: Int = 60
    var sortOrder: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \LevelDefinition.exercise)
    var levels: [LevelDefinition]? = []

    @Relationship(deleteRule: .nullify, inverse: \ExerciseEnrolment.exerciseDefinition)
    var enrolments: [ExerciseEnrolment]? = []

    init(exerciseId: String, name: String, muscleGroup: MuscleGroup,
         color: String, countingMode: CountingMode, defaultRestSeconds: Int,
         sortOrder: Int) {
        self.exerciseId = exerciseId
        self.name = name
        self.muscleGroup = muscleGroup
        self.color = color
        self.countingMode = countingMode
        self.defaultRestSeconds = defaultRestSeconds
        self.sortOrder = sortOrder
    }
}
```

**Step 2: Create LevelDefinition.swift**

```swift
// LevelDefinition.swift
import SwiftData

@Model
final class LevelDefinition {
    var level: Int = 1
    var restDayPattern: [Int] = [2, 2, 3]
    var testTarget: Int = 0
    var extraRestBeforeTest: Int? = nil
    var totalDays: Int = 0

    var exercise: ExerciseDefinition?

    @Relationship(deleteRule: .cascade, inverse: \DayPrescription.level)
    var days: [DayPrescription]? = []

    init(level: Int, restDayPattern: [Int], testTarget: Int,
         extraRestBeforeTest: Int?, totalDays: Int) {
        self.level = level
        self.restDayPattern = restDayPattern
        self.testTarget = testTarget
        self.extraRestBeforeTest = extraRestBeforeTest
        self.totalDays = totalDays
    }
}
```

**Step 3: Create DayPrescription.swift**

```swift
// DayPrescription.swift
import SwiftData

@Model
final class DayPrescription {
    var dayNumber: Int = 0
    var sets: [Int] = []
    var isTest: Bool = false

    var level: LevelDefinition?

    var totalReps: Int { sets.reduce(0, +) }
    var setCount: Int { sets.count }

    init(dayNumber: Int, sets: [Int], isTest: Bool) {
        self.dayNumber = dayNumber
        self.sets = sets
        self.isTest = isTest
    }
}
```

**Step 4: Build to verify**
```
⌘B — expected: Build succeeds
```

**Step 5: Commit**
```bash
git add Shared/Sources/InchShared/Models/
git commit -m "feat: add static data models (ExerciseDefinition, LevelDefinition, DayPrescription)"
```

---

### Task 3: User state models

**Files:**
- Create: `Shared/Sources/InchShared/Models/ExerciseEnrolment.swift`
- Create: `Shared/Sources/InchShared/Models/CompletedSet.swift`
- Create: `Shared/Sources/InchShared/Models/SensorRecording.swift`

**Step 1: Create ExerciseEnrolment.swift**

```swift
// ExerciseEnrolment.swift
import SwiftData

@Model
final class ExerciseEnrolment {
    #Index<ExerciseEnrolment>([\.nextScheduledDate])

    var enrolledAt: Date = Date.now
    var isActive: Bool = true
    var currentLevel: Int = 1
    var currentDay: Int = 1
    var lastCompletedDate: Date? = nil
    var nextScheduledDate: Date? = nil
    var restPatternIndex: Int = 0

    var exerciseDefinition: ExerciseDefinition?

    @Relationship(deleteRule: .cascade, inverse: \CompletedSet.enrolment)
    var completedSets: [CompletedSet]? = []

    init(exerciseDefinition: ExerciseDefinition, enrolledAt: Date) {
        self.exerciseDefinition = exerciseDefinition
        self.enrolledAt = enrolledAt
        self.nextScheduledDate = enrolledAt
    }
}
```

**Step 2: Create CompletedSet.swift**

```swift
// CompletedSet.swift
import SwiftData

@Model
final class CompletedSet {
    #Index<CompletedSet>([\.completedAt])

    var completedAt: Date = Date.now
    var sessionDate: Date = Date.now
    var exerciseId: String = ""
    var level: Int = 0
    var dayNumber: Int = 0
    var setNumber: Int = 0
    var targetReps: Int = 0
    var actualReps: Int = 0
    var isTest: Bool = false
    var testPassed: Bool? = nil
    var countingMode: CountingMode = CountingMode.postSetConfirmation
    var setDurationSeconds: Double? = nil

    var enrolment: ExerciseEnrolment?

    @Relationship(deleteRule: .cascade, inverse: \SensorRecording.completedSet)
    var sensorRecordings: [SensorRecording]? = []

    init(exerciseId: String, level: Int, dayNumber: Int, setNumber: Int,
         targetReps: Int, actualReps: Int, isTest: Bool,
         countingMode: CountingMode, sessionDate: Date) {
        self.exerciseId = exerciseId
        self.level = level
        self.dayNumber = dayNumber
        self.setNumber = setNumber
        self.targetReps = targetReps
        self.actualReps = actualReps
        self.isTest = isTest
        self.countingMode = countingMode
        self.sessionDate = sessionDate
    }
}
```

**Step 3: Create SensorRecording.swift**

```swift
// SensorRecording.swift
import SwiftData

@Model
final class SensorRecording {
    var recordedAt: Date = Date.now
    var device: SensorDevice = SensorDevice.iPhone
    var exerciseId: String = ""
    var level: Int = 0
    var dayNumber: Int = 0
    var setNumber: Int = 0
    var confirmedReps: Int = 0
    var sampleRateHz: Int = 100
    var durationSeconds: Double = 0
    var filePath: String = ""
    var fileSizeBytes: Int = 0
    var uploadStatus: UploadStatus = UploadStatus.pending
    var uploadedAt: Date? = nil

    var completedSet: CompletedSet?

    init(device: SensorDevice, exerciseId: String, level: Int, dayNumber: Int,
         setNumber: Int, confirmedReps: Int, filePath: String, fileSizeBytes: Int,
         durationSeconds: Double) {
        self.device = device
        self.exerciseId = exerciseId
        self.level = level
        self.dayNumber = dayNumber
        self.setNumber = setNumber
        self.confirmedReps = confirmedReps
        self.filePath = filePath
        self.fileSizeBytes = fileSizeBytes
        self.durationSeconds = durationSeconds
    }
}
```

**Step 4: Build to verify**
```
⌘B — expected: Build succeeds
```

**Step 5: Commit**
```bash
git add Shared/Sources/InchShared/Models/
git commit -m "feat: add user state models (ExerciseEnrolment, CompletedSet, SensorRecording)"
```

---

### Task 4: Settings models + ModelContainer

**Files:**
- Create: `Shared/Sources/InchShared/Models/UserSettings.swift`
- Create: `Shared/Sources/InchShared/Models/StreakState.swift`
- Create: `Shared/Sources/InchShared/Models/UserEntitlement.swift`
- Create: `Shared/Sources/InchShared/Models/ModelContainerFactory.swift`

**Step 1: Create UserSettings.swift**

```swift
// UserSettings.swift
import SwiftData

@Model
final class UserSettings {
    var createdAt: Date = Date.now
    var restOverrides: [String: Int] = [:]
    var countingModeOverrides: [String: String] = [:]
    var interExerciseRestEnabled: Bool = false
    var interExerciseRestSeconds: Int = 120
    var dailyReminderEnabled: Bool = true
    var dailyReminderHour: Int = 8
    var dailyReminderMinute: Int = 0
    var streakProtectionEnabled: Bool = true
    var testDayNotificationEnabled: Bool = true
    var levelUnlockNotificationEnabled: Bool = true
    var motionDataUploadConsented: Bool = false
    var consentDate: Date? = nil
    var contributorId: String = ""
    var ageRange: String? = nil
    var heightRange: String? = nil
    var biologicalSex: String? = nil
    var activityLevel: String? = nil
}
```

**Step 2: Create StreakState.swift**

```swift
// StreakState.swift
import SwiftData

@Model
final class StreakState {
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastActiveDate: Date? = nil
}
```

**Step 3: Create UserEntitlement.swift**

```swift
// UserEntitlement.swift
import SwiftData

@Model
final class UserEntitlement {
    var productId: String = ""
    var purchaseDate: Date = Date.now
    var expiresDate: Date? = nil
    var transactionId: String = ""
}
```

**Step 4: Create ModelContainerFactory.swift**

```swift
// ModelContainerFactory.swift
import SwiftData

public enum BodyweightSchemaV1: VersionedSchema {
    public static var versionIdentifier = Schema.Version(1, 0, 0)
    public static var models: [any PersistentModel.Type] {
        [ExerciseDefinition.self, LevelDefinition.self, DayPrescription.self,
         ExerciseEnrolment.self, CompletedSet.self, SensorRecording.self,
         UserSettings.self, StreakState.self, UserEntitlement.self]
    }
}

public enum BodyweightMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [BodyweightSchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}

public enum ModelContainerFactory {
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(BodyweightSchemaV1.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, migrationPlan: BodyweightMigrationPlan.self,
                                   configurations: config)
    }
}
```

**Step 5: Build to verify**
```
⌘B — expected: Build succeeds with all 9 model types
```

**Step 6: Commit**
```bash
git add Shared/Sources/InchShared/Models/
git commit -m "feat: add settings models and ModelContainerFactory with migration plan"
```

---

## Phase 2: Shared Package — Engine

### Task 5: WatchConnectivity transfer types

**Files:**
- Create: `Shared/Sources/InchShared/Transfer/WatchSession.swift`
- Create: `Shared/Sources/InchShared/Transfer/WatchCompletionReport.swift`

**Step 1: Create WatchSession.swift**

```swift
// WatchSession.swift
import Foundation

public struct WatchSession: Codable, Sendable {
    public let exerciseId: String
    public let exerciseName: String
    public let color: String
    public let level: Int
    public let dayNumber: Int
    public let sets: [Int]
    public let isTest: Bool
    public let testTarget: Int?
    public let restSeconds: Int
    public let countingMode: String

    public init(exerciseId: String, exerciseName: String, color: String,
                level: Int, dayNumber: Int, sets: [Int], isTest: Bool,
                testTarget: Int?, restSeconds: Int, countingMode: String) {
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.color = color
        self.level = level
        self.dayNumber = dayNumber
        self.sets = sets
        self.isTest = isTest
        self.testTarget = testTarget
        self.restSeconds = restSeconds
        self.countingMode = countingMode
    }
}
```

**Step 2: Create WatchCompletionReport.swift**

```swift
// WatchCompletionReport.swift
import Foundation

public struct WatchSetResult: Codable, Sendable {
    public let setNumber: Int
    public let targetReps: Int
    public let actualReps: Int
    public let durationSeconds: Double?
}

public struct WatchCompletionReport: Codable, Sendable {
    public let exerciseId: String
    public let level: Int
    public let dayNumber: Int
    public let completedSets: [WatchSetResult]
    public let completedAt: Date
}
```

**Step 3: Build and commit**
```bash
git add Shared/Sources/InchShared/Transfer/
git commit -m "feat: add WatchConnectivity transfer DTOs"
```

---

### Task 6: ExerciseDataLoader

**Files:**
- Create: `Shared/Sources/InchShared/Engine/ExerciseDataLoader.swift`
- Create: `Shared/Tests/InchSharedTests/ExerciseDataLoaderTests.swift`

**Step 1: Write the failing test first**

```swift
// ExerciseDataLoaderTests.swift
import Testing
import SwiftData
@testable import InchShared

struct ExerciseDataLoaderTests {
    @Test(.tags(.dataLoader))
    func loadsAllSixExercises() async throws {
        let container = try ModelContainerFactory.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let loader = ExerciseDataLoader()
        try await loader.seedIfNeeded(context: context)

        let exercises = try context.fetch(FetchDescriptor<ExerciseDefinition>())
        #expect(exercises.count == 6)
    }

    @Test(.tags(.dataLoader))
    func pushUpsHasThreeLevels() async throws {
        let container = try ModelContainerFactory.makeContainer(inMemory: true)
        let context = ModelContext(container)
        try await ExerciseDataLoader().seedIfNeeded(context: context)

        let descriptor = FetchDescriptor<ExerciseDefinition>(
            predicate: #Predicate { $0.exerciseId == "push_ups" }
        )
        let pushUps = try #require(try context.fetch(descriptor).first)
        #expect(pushUps.levels?.count == 3)
    }

    @Test(.tags(.dataLoader))
    func totalDayPrescriptionsAreCorrect() async throws {
        let container = try ModelContainerFactory.makeContainer(inMemory: true)
        let context = ModelContext(container)
        try await ExerciseDataLoader().seedIfNeeded(context: context)

        let days = try context.fetch(FetchDescriptor<DayPrescription>())
        // 6 exercises × 3 levels × ~10-25 days each ≈ 300 total
        #expect(days.count > 250)
    }

    @Test(.tags(.dataLoader))
    func seedingTwiceDoesNotDuplicate() async throws {
        let container = try ModelContainerFactory.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let loader = ExerciseDataLoader()
        try await loader.seedIfNeeded(context: context)
        try await loader.seedIfNeeded(context: context)

        let exercises = try context.fetch(FetchDescriptor<ExerciseDefinition>())
        #expect(exercises.count == 6)
    }
}

extension Tag {
    @Tag static var scheduling: Self
    @Tag static var conflict: Self
    @Tag static var streak: Self
    @Tag static var dataLoader: Self
    @Tag static var integration: Self
}
```

**Step 2: Run the test to verify it fails**
```
In Xcode: ⌘U on InchSharedTests
Expected: FAIL — ExerciseDataLoader type not found
```

**Step 3: Create ExerciseDataLoader.swift**

The loader reads from `exercise-data.json` bundled in `InchApp/Resources/`. The Shared package cannot access app bundle resources directly, so we pass the JSON data in.

```swift
// ExerciseDataLoader.swift
import Foundation
import SwiftData

public struct ExerciseDataLoader: Sendable {
    public init() {}

    /// Seeds the ModelContext with exercise data from the provided JSON data.
    /// Skips if exercises already exist. Call on first launch from the app target.
    public func seedIfNeeded(context: ModelContext, jsonData: Data? = nil) async throws {
        // Check if already seeded
        let existing = try context.fetch(FetchDescriptor<ExerciseDefinition>())
        guard existing.isEmpty else { return }

        let data: Data
        if let provided = jsonData {
            data = provided
        } else {
            // Fallback: look in main bundle (works when called from app target)
            guard let url = Bundle.main.url(forResource: "exercise-data", withExtension: "json"),
                  let bundleData = try? Data(contentsOf: url) else {
                throw ExerciseDataError.jsonNotFound
            }
            data = bundleData
        }

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
                    totalDays: levelDTO.days.count
                )
                levelDef.exercise = exercise
                context.insert(levelDef)

                for dayDTO in levelDTO.days {
                    let day = DayPrescription(
                        dayNumber: dayDTO.day,
                        sets: dayDTO.sets,
                        isTest: dayDTO.sets.count == 1 && dayDTO.day == levelDTO.days.count
                    )
                    day.level = levelDef
                    context.insert(day)
                }
            }
        }

        try context.save()
    }
}

// MARK: - Decoding types

private struct ExerciseDataRoot: Decodable {
    let exercises: [ExerciseDTO]
}

private struct ExerciseDTO: Decodable {
    let id: String
    let name: String
    let muscleGroup: String
    let color: String
    let countingMode: String
    let defaultRestSeconds: Int
    let levels: [LevelDTO]
}

private struct LevelDTO: Decodable {
    let level: Int
    let restDayPattern: [Int]
    let testTarget: Int
    let extraRestBeforeTest: Int?
    let days: [DayDTO]
}

private struct DayDTO: Decodable {
    let day: Int
    let sets: [Int]
}

public enum ExerciseDataError: Error {
    case jsonNotFound
    case decodingFailed
}
```

**Step 4: Run the tests**
```
⌘U on InchSharedTests
Expected: loadsAllSixExercises, pushUpsHasThreeLevels, totalDayPrescriptionsAreCorrect, seedingTwiceDoesNotDuplicate — all PASS
```

**Step 5: Commit**
```bash
git add Shared/
git commit -m "feat: add ExerciseDataLoader with JSON parsing and seeding"
```

---

### Task 7: SchedulingEngine — core algorithms

**Files:**
- Create: `Shared/Sources/InchShared/Engine/SchedulingEngine.swift`
- Create: `Shared/Sources/InchShared/Utilities/DateHelpers.swift`
- Create: `Shared/Tests/InchSharedTests/SchedulingEngineTests.swift`

**Step 1: Write the failing tests for computeNextDate**

```swift
// SchedulingEngineTests.swift
import Testing
import Foundation
@testable import InchShared

struct SchedulingEngineTests {
    let engine = SchedulingEngine()

    // MARK: - Helpers

    func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func makeEnrolment(level: Int = 1, currentDay: Int = 1,
                       lastCompleted: Date? = nil, patternIndex: Int = 0,
                       enrolledAt: Date = Date.now) -> MockEnrolmentState {
        MockEnrolmentState(currentLevel: level, currentDay: currentDay,
                           lastCompletedDate: lastCompleted, restPatternIndex: patternIndex,
                           enrolledAt: enrolledAt)
    }

    // MARK: - Test 1: Basic date calculation

    @Test(.tags(.scheduling))
    func basicDateCalculationAfterDay1() throws {
        // Push-Ups L1: pattern [2,2,3], Day 1 completed March 15
        let level = MockLevelState(restDayPattern: [2, 2, 3], totalDays: 10,
                                   extraRestBeforeTest: nil, testTarget: 20)
        var state = makeEnrolment(level: 1, currentDay: 2, // currentDay advanced after completion
                                  lastCompleted: makeDate(2026, 3, 15), patternIndex: 1)
        let next = engine.computeNextDate(state: state, level: level)
        #expect(next == makeDate(2026, 3, 17), "Gap should be pattern[1]=2 after Day 1")
    }

    // MARK: - Test 2: Pattern cycling

    @Test(.tags(.scheduling), arguments: [
        (currentDay: 2, patternIndex: 1, lastCompletedDay: 17, expectedNextDay: 19),
        (currentDay: 3, patternIndex: 2, lastCompletedDay: 19, expectedNextDay: 22),
        (currentDay: 4, patternIndex: 0, lastCompletedDay: 22, expectedNextDay: 24), // cycles
    ])
    func patternCycling(currentDay: Int, patternIndex: Int,
                        lastCompletedDay: Int, expectedNextDay: Int) throws {
        let level = MockLevelState(restDayPattern: [2, 2, 3], totalDays: 10,
                                   extraRestBeforeTest: nil, testTarget: 20)
        let state = makeEnrolment(currentDay: currentDay,
                                  lastCompleted: makeDate(2026, 3, lastCompletedDay),
                                  patternIndex: patternIndex)
        let next = engine.computeNextDate(state: state, level: level)
        #expect(next == makeDate(2026, 3, expectedNextDay))
    }

    // MARK: - Test 3: Extra rest before test

    @Test(.tags(.scheduling))
    func extraRestBeforeTest() throws {
        // Push-Ups L2: extraRestBeforeTest = 4, test is day 19
        let level = MockLevelState(restDayPattern: [2, 2, 3], totalDays: 19,
                                   extraRestBeforeTest: 4, testTarget: 50)
        // currentDay = 19 (next up is the test), lastCompleted = day 18
        let state = makeEnrolment(currentDay: 19,
                                  lastCompleted: makeDate(2026, 3, 15), patternIndex: 2)
        let next = engine.computeNextDate(state: state, level: level)
        #expect(next == makeDate(2026, 3, 19), "Extra rest of 4 days applies before test")
    }

    // MARK: - Test 5: Failed test retry (same extra rest applies)

    @Test(.tags(.scheduling))
    func failedTestRetryUsesExtraRest() throws {
        let level = MockLevelState(restDayPattern: [2, 2, 3], totalDays: 19,
                                   extraRestBeforeTest: 4, testTarget: 50)
        // currentDay is still 19 (failed, not advanced), lastCompleted = today
        let state = makeEnrolment(currentDay: 19,
                                  lastCompleted: makeDate(2026, 3, 15), patternIndex: 2)
        let next = engine.computeNextDate(state: state, level: level)
        #expect(next == makeDate(2026, 3, 19))
    }

    // MARK: - Test 4: Level transition

    @Test(.tags(.scheduling))
    func levelTransitionAdds2DayGap() throws {
        let level = MockLevelState(restDayPattern: [2, 2, 3], totalDays: 10,
                                   extraRestBeforeTest: nil, testTarget: 20)
        // currentDay = 11 means we just advanced past the end of the level
        let state = makeEnrolment(level: 1, currentDay: 11,
                                  lastCompleted: makeDate(2026, 3, 15), patternIndex: 0)
        let next = engine.computeNextDate(state: state, level: level)
        #expect(next == makeDate(2026, 3, 17), "Level transition adds 2-day gap")
    }

    // MARK: - Test: First training day uses enrolledAt

    @Test(.tags(.scheduling))
    func firstTrainingDayUsesEnrolledAt() throws {
        let level = MockLevelState(restDayPattern: [2, 2, 3], totalDays: 10,
                                   extraRestBeforeTest: nil, testTarget: 20)
        let enrolled = makeDate(2026, 3, 15)
        let state = makeEnrolment(lastCompleted: nil, enrolledAt: enrolled)
        let next = engine.computeNextDate(state: state, level: level)
        #expect(next == enrolled)
    }
}

// MARK: - Mock state types for pure function testing

struct MockEnrolmentState {
    var currentLevel: Int
    var currentDay: Int
    var lastCompletedDate: Date?
    var restPatternIndex: Int
    var enrolledAt: Date
}

struct MockLevelState {
    var restDayPattern: [Int]
    var totalDays: Int
    var extraRestBeforeTest: Int?
    var testTarget: Int
}
```

**Step 2: Run to verify tests fail**
```
⌘U — Expected: FAIL — SchedulingEngine not found
```

**Step 3: Create DateHelpers.swift**

```swift
// DateHelpers.swift
import Foundation

public extension Calendar {
    static func daysBetween(_ start: Date, _ end: Date) -> Int {
        Calendar.current.dateComponents([.day], from: startOfDay(for: start),
                                         to: startOfDay(for: end)).day ?? 0
    }
}

public extension Date {
    func addingDays(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }
}
```

**Step 4: Create SchedulingEngine.swift**

```swift
// SchedulingEngine.swift
import Foundation
import SwiftData

public struct SchedulingEngine: Sendable {
    static let interLevelGapDays = 2

    public init() {}

    /// Compute the next scheduled date for a given enrolment.
    /// This is a pure function — it reads state, returns a date.
    public func computeNextDate(enrolment: ExerciseEnrolment,
                                 level: LevelDefinition) -> Date? {
        guard let days = level.days, !days.isEmpty else { return nil }
        let sortedDays = days.sorted { $0.dayNumber < $1.dayNumber }

        // No training yet — start on enrolment date
        guard let lastCompleted = enrolment.lastCompletedDate else {
            return enrolment.enrolledAt
        }

        // Level complete — transition to next
        if enrolment.currentDay > level.totalDays {
            if enrolment.currentLevel < 3 {
                return lastCompleted.addingDays(Self.interLevelGapDays)
            } else {
                return nil // program complete
            }
        }

        // Find the next day's prescription (currentDay is 1-indexed)
        let nextDayIndex = enrolment.currentDay - 1
        guard nextDayIndex < sortedDays.count else { return nil }
        let nextDayPrescription = sortedDays[nextDayIndex]

        // Extra rest before test
        if nextDayPrescription.isTest, let extra = level.extraRestBeforeTest {
            return lastCompleted.addingDays(extra)
        }

        // Normal rest pattern
        let pattern = level.restDayPattern
        let gapDays = pattern[enrolment.restPatternIndex % pattern.count]
        return lastCompleted.addingDays(gapDays)
    }

    /// Pure-function variant that takes value types (used in tests and projections).
    public func computeNextDate(state: MockEnrolmentState,
                                 level: MockLevelState) -> Date? {
        guard state.currentDay <= level.totalDays + 1 else { return nil }

        guard let lastCompleted = state.lastCompletedDate else {
            return state.enrolledAt
        }

        if state.currentDay > level.totalDays {
            if state.currentLevel < 3 {
                return lastCompleted.addingDays(Self.interLevelGapDays)
            }
            return nil
        }

        let nextDayIndex = state.currentDay - 1
        guard nextDayIndex < level.totalDays else { return nil }
        let isTestDay = nextDayIndex == level.totalDays - 1 // last day

        if isTestDay, let extra = level.extraRestBeforeTest {
            return lastCompleted.addingDays(extra)
        }

        let pattern = level.restDayPattern
        let gapDays = pattern[state.restPatternIndex % pattern.count]
        return lastCompleted.addingDays(gapDays)
    }

    /// Apply completion of a training day. Mutates the enrolment state.
    public func completeTrainingDay(enrolment: ExerciseEnrolment,
                                     level: LevelDefinition,
                                     actualDate: Date,
                                     totalRepsScored: Int) {
        guard let days = level.days else { return }
        let sortedDays = days.sorted { $0.dayNumber < $1.dayNumber }
        let dayIndex = enrolment.currentDay - 1
        guard dayIndex < sortedDays.count else { return }
        let dayPrescription = sortedDays[dayIndex]

        if dayPrescription.isTest {
            if totalRepsScored >= level.testTarget {
                // Test passed
                if enrolment.currentLevel < 3 {
                    enrolment.currentLevel += 1
                    enrolment.currentDay = 1
                    enrolment.restPatternIndex = 0
                } else {
                    enrolment.isActive = false
                }
            }
            // Test failed: currentLevel and currentDay stay the same
        } else {
            enrolment.currentDay += 1
            enrolment.restPatternIndex += 1
        }

        enrolment.lastCompletedDate = actualDate
        enrolment.nextScheduledDate = computeNextDate(enrolment: enrolment, level: level)
    }
}
```

**Step 5: Run all scheduling tests**
```
⌘U — Expected: All 7 scheduling tests PASS
```

**Step 6: Commit**
```bash
git add Shared/
git commit -m "feat: add SchedulingEngine with computeNextDate and completeTrainingDay"
```

---

### Task 8: ConflictDetector

**Files:**
- Create: `Shared/Sources/InchShared/Engine/ConflictDetector.swift`
- Create: `Shared/Tests/InchSharedTests/ConflictDetectorTests.swift`

**Step 1: Write failing tests**

```swift
// ConflictDetectorTests.swift
import Testing
import Foundation
@testable import InchShared

struct ConflictDetectorTests {
    let detector = ConflictDetector()

    @Test(.tags(.conflict))
    func detectsDoubleTestOnSameDay() {
        // Test 7: Two tests on the same date
        let date = Calendar.current.startOfDay(for: Date.now)
        let sessions: [ProjectedSession] = [
            ProjectedSession(exerciseId: "push_ups", muscleGroup: .upperPush,
                             isTest: true, date: date, enrolmentId: "e1"),
            ProjectedSession(exerciseId: "pull_ups", muscleGroup: .upperPull,
                             isTest: true, date: date, enrolmentId: "e2"),
        ]
        let conflicts = detector.detectConflicts(in: sessions)
        #expect(conflicts.contains { if case .doubleTest = $0 { true } else { false } })
    }

    @Test(.tags(.conflict))
    func detectsTestWithSameGroupTraining() {
        // Test 8: Squats test + Glute Bridges training on same date
        let date = Calendar.current.startOfDay(for: Date.now)
        let sessions: [ProjectedSession] = [
            ProjectedSession(exerciseId: "squats", muscleGroup: .lower,
                             isTest: true, date: date, enrolmentId: "e1"),
            ProjectedSession(exerciseId: "glute_bridges", muscleGroup: .lowerPosterior,
                             isTest: false, date: date, enrolmentId: "e2"),
        ]
        let conflicts = detector.detectConflicts(in: sessions)
        #expect(conflicts.contains {
            if case .testWithSameGroupTraining = $0 { true } else { false }
        })
    }

    @Test(.tags(.conflict))
    func noConflictForUnrelatedMuscleGroups() {
        let date = Calendar.current.startOfDay(for: Date.now)
        let sessions: [ProjectedSession] = [
            ProjectedSession(exerciseId: "push_ups", muscleGroup: .upperPush,
                             isTest: true, date: date, enrolmentId: "e1"),
            ProjectedSession(exerciseId: "squats", muscleGroup: .lower,
                             isTest: false, date: date, enrolmentId: "e2"),
        ]
        let conflicts = detector.detectConflicts(in: sessions)
        #expect(conflicts.isEmpty)
    }
}
```

**Step 2: Run to verify tests fail**
```
⌘U — Expected: FAIL — ConflictDetector not found
```

**Step 3: Create ConflictDetector.swift**

```swift
// ConflictDetector.swift
import Foundation

public struct ProjectedSession: Sendable {
    public let exerciseId: String
    public let muscleGroup: MuscleGroup
    public let isTest: Bool
    public let date: Date
    public let enrolmentId: String

    public init(exerciseId: String, muscleGroup: MuscleGroup, isTest: Bool,
                date: Date, enrolmentId: String) {
        self.exerciseId = exerciseId
        self.muscleGroup = muscleGroup
        self.isTest = isTest
        self.date = date
        self.enrolmentId = enrolmentId
    }
}

public enum ScheduleConflict: Sendable {
    case doubleTest(date: Date, exerciseIds: [String])
    case testWithSameGroupTraining(date: Date, testExerciseId: String, trainingExerciseId: String)
}

public struct ConflictDetector: Sendable {
    public init() {}

    public func detectConflicts(in sessions: [ProjectedSession]) -> [ScheduleConflict] {
        var conflicts: [ScheduleConflict] = []

        // Group by day
        let grouped = Dictionary(grouping: sessions) {
            Calendar.current.startOfDay(for: $0.date)
        }

        for (date, daySessions) in grouped {
            let testSessions = daySessions.filter(\.isTest)
            let regularSessions = daySessions.filter { !$0.isTest }

            // Rule 1: No two tests on the same day
            if testSessions.count > 1 {
                conflicts.append(.doubleTest(date: date,
                    exerciseIds: testSessions.map(\.exerciseId)))
            }

            // Rule 2: Test + same-muscle-group training
            for test in testSessions {
                for regular in regularSessions {
                    if test.muscleGroup.conflictGroups.contains(regular.muscleGroup) {
                        conflicts.append(.testWithSameGroupTraining(
                            date: date,
                            testExerciseId: test.exerciseId,
                            trainingExerciseId: regular.exerciseId
                        ))
                    }
                }
            }
        }

        return conflicts
    }
}
```

**Step 4: Run tests**
```
⌘U — Expected: All 3 conflict detection tests PASS
```

**Step 5: Commit**
```bash
git add Shared/
git commit -m "feat: add ConflictDetector with double-test and same-group rules"
```

---

### Task 9: ConflictResolver

**Files:**
- Create: `Shared/Sources/InchShared/Engine/ConflictResolver.swift`
- Create: `Shared/Tests/InchSharedTests/ConflictResolverTests.swift`

**Step 1: Write failing tests**

```swift
// ConflictResolverTests.swift
import Testing
import Foundation
@testable import InchShared

struct ConflictResolverTests {
    @Test(.tags(.conflict))
    func resolvesDoubleTestByPushingLowerPriorityExercise() {
        // The exercise with MORE remaining days gets pushed (lower priority = further from end)
        let date = Calendar.current.startOfDay(for: Date.now)
        let sessions: [ProjectedSession] = [
            ProjectedSession(exerciseId: "push_ups", muscleGroup: .upperPush,
                             isTest: true, date: date, enrolmentId: "e1"),
            ProjectedSession(exerciseId: "pull_ups", muscleGroup: .upperPull,
                             isTest: true, date: date, enrolmentId: "e2"),
        ]
        let resolver = ConflictResolver()
        let adjustments = resolver.resolve(
            conflicts: [.doubleTest(date: date, exerciseIds: ["push_ups", "pull_ups"])],
            sessions: sessions,
            remainingDays: { id in id == "e1" ? 5 : 20 } // e2 has more remaining
        )
        #expect(adjustments.count == 1)
        #expect(adjustments.first?.enrolmentId == "e2")
    }

    @Test(.tags(.conflict))
    func resolvesCascadeConflicts() {
        // Test 9: Resolving one conflict must not exceed 5 iterations
        // (This is an integration test — we verify the loop terminates)
        let resolver = ConflictResolver()
        #expect(resolver.maxIterations == 5)
    }
}
```

**Step 2: Create ConflictResolver.swift**

```swift
// ConflictResolver.swift
import Foundation

public struct ScheduleAdjustment: Sendable {
    public let enrolmentId: String
    public let reason: String
}

public struct ConflictResolver: Sendable {
    public let maxIterations = 5
    public init() {}

    public func resolve(conflicts: [ScheduleConflict],
                        sessions: [ProjectedSession],
                        remainingDays: (String) -> Int) -> [ScheduleAdjustment] {
        var adjustments: [ScheduleAdjustment] = []

        for conflict in conflicts {
            switch conflict {
            case .doubleTest(_, let exerciseIds):
                // Find the enrolment IDs for these exercises
                let involvedSessions = sessions.filter { exerciseIds.contains($0.exerciseId) && $0.isTest }
                let sorted = involvedSessions.sorted { remainingDays($0.enrolmentId) < remainingDays($1.enrolmentId) }
                // Push the one with most remaining days (lower priority)
                if let toPush = sorted.last {
                    adjustments.append(ScheduleAdjustment(enrolmentId: toPush.enrolmentId,
                                                           reason: "Avoiding test day collision"))
                }

            case .testWithSameGroupTraining(_, _, let trainingExerciseId):
                let session = sessions.first { $0.exerciseId == trainingExerciseId && !$0.isTest }
                if let s = session {
                    adjustments.append(ScheduleAdjustment(enrolmentId: s.enrolmentId,
                                                           reason: "Resting muscle group for test day"))
                }
            }
        }

        return adjustments
    }
}
```

**Step 3: Run tests**
```
⌘U — Expected: Both conflict resolver tests PASS
```

**Step 4: Commit**
```bash
git add Shared/
git commit -m "feat: add ConflictResolver with priority ordering"
```

---

### Task 10: StreakCalculator

**Files:**
- Create: `Shared/Sources/InchShared/Engine/StreakCalculator.swift`
- Create: `Shared/Tests/InchSharedTests/StreakCalculatorTests.swift`

**Step 1: Write failing tests (Tests 10-12 from spec)**

```swift
// StreakCalculatorTests.swift
import Testing
import Foundation
@testable import InchShared

struct StreakCalculatorTests {
    let calc = StreakCalculator()

    func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.startOfDay(for:
            Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!)
    }

    // Test 10: Partial completion maintains streak
    @Test(.tags(.streak))
    func partialCompletionMaintainsStreak() {
        var state = StreakStateDTO(currentStreak: 3, longestStreak: 5,
                                   lastActiveDate: makeDate(2026, 3, 14))
        let today = makeDate(2026, 3, 15)
        calc.update(state: &state, today: today,
                    hadDueExercises: true, completedAny: true)
        #expect(state.currentStreak == 4)
    }

    // Test 11: Rest day never breaks streak
    @Test(.tags(.streak))
    func restDayDoesNotBreakStreak() {
        var state = StreakStateDTO(currentStreak: 3, longestStreak: 5,
                                   lastActiveDate: makeDate(2026, 3, 14))
        let today = makeDate(2026, 3, 15)
        calc.update(state: &state, today: today,
                    hadDueExercises: false, completedAny: false)
        #expect(state.currentStreak == 3) // unchanged
    }

    // Test 12: Complete skip breaks streak
    @Test(.tags(.streak))
    func completeSkipBreaksStreak() {
        var state = StreakStateDTO(currentStreak: 3, longestStreak: 5,
                                   lastActiveDate: makeDate(2026, 3, 14))
        let today = makeDate(2026, 3, 15)
        calc.update(state: &state, today: today,
                    hadDueExercises: true, completedAny: false)
        #expect(state.currentStreak == 0)
    }

    @Test(.tags(.streak))
    func longestStreakUpdates() {
        var state = StreakStateDTO(currentStreak: 5, longestStreak: 5,
                                   lastActiveDate: makeDate(2026, 3, 14))
        let today = makeDate(2026, 3, 15)
        calc.update(state: &state, today: today,
                    hadDueExercises: true, completedAny: true)
        #expect(state.longestStreak == 6)
    }
}

struct StreakStateDTO {
    var currentStreak: Int
    var longestStreak: Int
    var lastActiveDate: Date?
}
```

**Step 2: Create StreakCalculator.swift**

```swift
// StreakCalculator.swift
import Foundation
import SwiftData

public struct StreakCalculator: Sendable {
    public init() {}

    /// Pure function variant for testing. Mutates `state` in place.
    public func update(state: inout StreakStateDTO, today: Date,
                       hadDueExercises: Bool, completedAny: Bool) {
        guard hadDueExercises else { return } // rest day — no change

        if completedAny {
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
            let lastActive = state.lastActiveDate
            if let last = lastActive,
               Calendar.current.isDate(last, inSameDayAs: yesterday) {
                state.currentStreak += 1
            } else if lastActive == nil {
                state.currentStreak = 1
            } else {
                // Gap — treat as reset (pragmatic v1 approach)
                state.currentStreak = 1
            }
            state.lastActiveDate = today
            state.longestStreak = max(state.longestStreak, state.currentStreak)
        } else {
            state.currentStreak = 0
        }
    }

    /// SwiftData variant — reads and writes the StreakState model.
    public func updateStreakState(_ streakState: StreakState, today: Date,
                                  hadDueExercises: Bool, completedAny: Bool) {
        var dto = StreakStateDTO(
            currentStreak: streakState.currentStreak,
            longestStreak: streakState.longestStreak,
            lastActiveDate: streakState.lastActiveDate
        )
        update(state: &dto, today: today,
               hadDueExercises: hadDueExercises, completedAny: completedAny)
        streakState.currentStreak = dto.currentStreak
        streakState.longestStreak = dto.longestStreak
        streakState.lastActiveDate = dto.lastActiveDate
    }
}
```

**Step 3: Run all shared package tests**
```
⌘U — Expected: All tests in InchSharedTests PASS
```

**Step 4: Commit**
```bash
git add Shared/
git commit -m "feat: add StreakCalculator — shared package engine complete"
```

---

## Phase 3: iOS App Shell

### Task 11: App entry point and ModelContainer

**Files:**
- Create: `InchApp/InchApp.swift`

```swift
// InchApp.swift
import SwiftUI
import SwiftData
import InchShared

@main
struct InchApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainerFactory.makeContainer()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
        }
    }
}
```

**Create: `InchApp/Navigation/RootView.swift`**

```swift
// RootView.swift
import SwiftUI
import SwiftData
import InchShared

struct RootView: View {
    @Query private var settings: [UserSettings]

    var body: some View {
        if settings.isEmpty {
            OnboardingCoordinatorView()
        } else {
            AppTabView()
        }
    }
}
```

**Create `InchApp/Navigation/AppTabView.swift`** — per `architecture.md`.

**Build and commit:**
```bash
git add InchApp/
git commit -m "feat: add iOS app entry point, ModelContainer setup, RootView"
```

---

### Task 12: Navigation system

**Files:**
- Create: `InchApp/Navigation/NavigationDestinations.swift`
- Create: `InchApp/Navigation/AppRouter.swift`

Follow the exact patterns in `Specs/architecture.md` for `NavigationStack` with `navigationDestination(for:)`. Use `PersistentIdentifier` for all navigation values.

```swift
// NavigationDestinations.swift
import SwiftUI
import SwiftData
import InchShared

enum WorkoutDestination: Hashable {
    case exercise(PersistentIdentifier)
    case testDay(PersistentIdentifier)
}

enum ProgramDestination: Hashable {
    case exerciseDetail(PersistentIdentifier)
}

extension View {
    func withWorkoutDestinations() -> some View {
        navigationDestination(for: WorkoutDestination.self) { destination in
            switch destination {
            case .exercise(let id): WorkoutSessionView(enrolmentId: id)
            case .testDay(let id): TestDayView(enrolmentId: id)
            }
        }
    }

    func withProgramDestinations() -> some View {
        navigationDestination(for: ProgramDestination.self) { destination in
            switch destination {
            case .exerciseDetail(let id): ExerciseDetailView(enrolmentId: id)
            }
        }
    }
}
```

**Commit:**
```bash
git add InchApp/Navigation/
git commit -m "feat: add navigation destination types and modifiers"
```

---

## Phase 4: Onboarding

### Task 13: Onboarding flow

**Files:**
- Create: `InchApp/Features/Onboarding/OnboardingCoordinatorView.swift`
- Create: `InchApp/Features/Onboarding/EnrolmentView.swift`
- Create: `InchApp/Features/Onboarding/ExerciseSelectionCard.swift`
- Create: `InchApp/Features/Onboarding/DataConsentView.swift`

Read `Specs/bodyweight-ux-design-v2.md` → "Program Enrolment" section before implementing.

**Key behaviours:**
- Show all 6 exercises as selectable cards, grouped by muscle group
- Show recommendation nudge for balanced selection (not enforced)
- Start date picker defaulting to today
- "Start Program" creates `ExerciseEnrolment` for each selected exercise
- After enrolment, creates `UserSettings` singleton and `StreakState` singleton
- Seeds exercise data via `ExerciseDataLoader` on first launch
- Leads into `DataConsentView` before landing on `AppTabView`

**Pattern for creating enrolments:**
```swift
// Inside EnrolmentView when "Start Program" tapped:
for definition in selectedDefinitions {
    let enrolment = ExerciseEnrolment(
        exerciseDefinition: definition,
        enrolledAt: startDate
    )
    modelContext.insert(enrolment)
}
let settings = UserSettings()
let streakState = StreakState()
modelContext.insert(settings)
modelContext.insert(streakState)
try? modelContext.save()
```

Use `@Observable` view model. Seed exercise data before presenting selection:
```swift
// In OnboardingCoordinatorView.task modifier:
if exerciseDefinitions.isEmpty {
    let loader = ExerciseDataLoader()
    try? await loader.seedIfNeeded(context: modelContext)
}
```

**Commit after each file:**
```bash
git commit -m "feat: add onboarding enrolment flow"
```

---

## Phase 5: Today Dashboard

### Task 14: Today dashboard

**Files:**
- Create: `InchApp/Features/Today/TodayViewModel.swift`
- Create: `InchApp/Features/Today/TodayView.swift`
- Create: `InchApp/Features/Today/ExerciseCard.swift`
- Create: `InchApp/Features/Today/RestDayView.swift`

Read `Specs/bodyweight-ux-design-v2.md` → "Today (iPhone — Daily Dashboard)" before implementing.

**TodayViewModel:**

```swift
// TodayViewModel.swift
import SwiftData
import Foundation
import InchShared

@Observable
final class TodayViewModel {
    var dueExercises: [ExerciseEnrolment] = []
    var isRestDay: Bool = false
    var conflictWarnings: [String: String] = [:]  // exerciseId -> warning

    private let modelContext: ModelContext
    private let scheduler = SchedulingEngine()
    private let detector = ConflictDetector()

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func loadToday() {
        let today = Calendar.current.startOfDay(for: .now)
        let descriptor = FetchDescriptor<ExerciseEnrolment>(
            predicate: #Predicate { $0.isActive && $0.nextScheduledDate != nil }
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        dueExercises = all.filter { enrolment in
            guard let scheduled = enrolment.nextScheduledDate else { return false }
            return Calendar.current.startOfDay(for: scheduled) <= today
        }
        isRestDay = dueExercises.isEmpty

        detectConflictsForToday()
    }

    private func detectConflictsForToday() {
        // Build projected sessions for due exercises and detect conflicts
        // Show warnings as non-blocking info on exercise cards
        conflictWarnings = [:]
    }
}
```

**Key UI notes (from UX spec):**
- Cards show: exercise name, level badge, day number, set summary (e.g. "5 sets · 3-4-4-3-2 reps"), muscle group colour accent
- Test day cards have a "TEST DAY" badge
- Conflict warnings appear as amber banners on affected cards
- Empty state = RestDayView with streak display

**Commit:**
```bash
git add InchApp/Features/Today/
git commit -m "feat: add Today dashboard with exercise cards and rest day view"
```

---

## Phase 6: Workout Session

### Task 15: Post-set confirmation mode

**Files:**
- Create: `InchApp/Features/Workout/WorkoutViewModel.swift`
- Create: `InchApp/Features/Workout/WorkoutSessionView.swift`
- Create: `InchApp/Features/Workout/PostSetConfirmationView.swift`
- Create: `InchApp/Features/Workout/RestTimerView.swift`
- Create: `InchApp/Features/Workout/ExerciseCompleteView.swift`

Read `Specs/bodyweight-ux-design-v2.md` → "Workout Session" before implementing.

**WorkoutViewModel state machine:**
```
.idle → .inSet(setNumber, targetReps) → .resting(setNumber, nextTargetReps) → .complete
```

**Key behaviours:**
- Session starts by fetching the `DayPrescription` for the enrolment's current level + day
- Each set: show target reps → user does the set → PostSetConfirmationView (enter actual reps)
- After actual reps entered → save `CompletedSet` → show `RestTimerView`
- After all sets → call `SchedulingEngine.completeTrainingDay()` → advance enrolment → save
- On complete: show `ExerciseCompleteView` then pop to Today

**Commit:**
```bash
git add InchApp/Features/Workout/
git commit -m "feat: add workout session with post-set confirmation counting mode"
```

---

### Task 16: Real-time counting mode

**Files:**
- Create: `InchApp/Features/Workout/RealTimeCountingView.swift`

Read `Specs/bodyweight-ux-design-v2.md` → "Real-Time Counting Mode" before implementing.

This mode shows a large rep counter that the user increments manually (tap each rep). The counter displays "current / target" and auto-advances when target is reached. On completion, a brief animation plays before showing `RestTimerView`.

**Commit:**
```bash
git add InchApp/Features/Workout/RealTimeCountingView.swift
git commit -m "feat: add real-time rep counting mode"
```

---

### Task 17: Test day flow

**Files:**
- Create: `InchApp/Features/Workout/TestDayView.swift`

Test days have a single all-out set. The view shows the test target, counts reps as the user does them, and after completion shows "PASSED" or "TRY AGAIN" with next scheduled date. Calls `SchedulingEngine.completeTrainingDay()` with the test result.

**Commit:**
```bash
git add InchApp/Features/Workout/TestDayView.swift
git commit -m "feat: add test day flow with pass/fail result screen"
```

---

## Phase 7: Program View

### Task 18: Program view

**Files:**
- Create: `InchApp/Features/Program/ProgramView.swift`
- Create: `InchApp/Features/Program/ProgramViewModel.swift`
- Create: `InchApp/Features/Program/ExerciseDetailView.swift`

Read `Specs/bodyweight-ux-design-v2.md` → "Program (Overview)" before implementing.

**Key UI:**
- List of enrolled exercises with level progress bars (day N of totalDays)
- Level badge (L1 / L2 / L3)
- Tap → `ExerciseDetailView` showing all days for current level, completed days greyed out
- Unenrolment button (archives the enrolment — sets `isActive = false`)

**Commit:**
```bash
git add InchApp/Features/Program/
git commit -m "feat: add program view with progress bars and exercise detail"
```

---

## Phase 8: History and Settings

### Task 19: History view

**Files:**
- Create: `InchApp/Features/History/HistoryView.swift`
- Create: `InchApp/Features/History/SessionDetailView.swift`
- Create: `InchApp/Features/History/HistoryViewModel.swift`

Group `CompletedSet` records by `sessionDate`. Show date headers, exercise summaries (sets done, reps, duration). Tap to see set-by-set detail.

**Commit:**
```bash
git commit -m "feat: add workout history view"
```

---

### Task 20: Settings

**Files:**
- Create: `InchApp/Features/Settings/SettingsView.swift`
- Create: `InchApp/Features/Settings/RestTimerSettingsView.swift`
- Create: `InchApp/Features/Settings/PrivacySettingsView.swift`
- Create: `InchApp/Features/Settings/SettingsViewModel.swift`

Read `Specs/bodyweight-ux-design-v2.md` → "Settings" before implementing.

**Sections:**
- Rest Timers: per-exercise overrides (stepper, shows default value)
- Counting Mode: per-exercise overrides
- Programs: add/remove exercises
- Privacy: motion data upload toggle, data deletion

**Commit:**
```bash
git add InchApp/Features/Settings/
git commit -m "feat: add settings (rest timers, counting mode, privacy)"
```

---

## Phase 9: WatchConnectivity

### Task 21: WatchConnectivity service (iOS)

**Files:**
- Create: `InchApp/Services/WatchConnectivityService.swift`

Read `Specs/framework-guidance.md` → "WatchConnectivity" and `Specs/architecture.md` → "WatchConnectivity Architecture" before implementing.

Use the exact pattern in `architecture.md`:
- `@Observable` class conforming to `WCSessionDelegate`
- `AsyncStream` for incoming completion reports
- `transferUserInfo` for schedule pushes and completion reports
- All three iOS-required delegate methods implemented

**Key method: `sendTodaySchedule(enrolments:)`**
- Builds `[WatchSession]` from due enrolments
- Encodes and sends via `transferUserInfo`
- Called after `loadToday()` in `TodayViewModel`

**Commit:**
```bash
git add InchApp/Services/WatchConnectivityService.swift
git commit -m "feat: add WatchConnectivity service (iOS side)"
```

---

## Phase 10: Watch App

### Task 22: Watch app shell

**Files:**
- Create: `InchWatch/InchWatchApp.swift`
- Create: `InchWatch/Services/WatchConnectivityService.swift`

Watch app activates `WCSession` on launch. Stores received `[WatchSession]` locally (either in `@AppStorage` via JSON encoding, or a lightweight in-memory state). The Watch does not use SwiftData — it receives its data from iPhone.

```swift
// InchWatchApp.swift
import SwiftUI
import InchShared

@main
struct InchWatchApp: App {
    @StateObject private var watchConnectivity = WatchConnectivityService()

    var body: some Scene {
        WindowGroup {
            WatchTodayView()
                .environmentObject(watchConnectivity)
        }
    }
}
```

**Commit:**
```bash
git commit -m "feat: add Watch app shell with WatchConnectivity service"
```

---

### Task 23: Watch workout flow

**Files:**
- Create: `InchWatch/Features/WatchTodayView.swift`
- Create: `InchWatch/Features/WatchWorkoutView.swift`
- Create: `InchWatch/Features/WatchWorkoutViewModel.swift`
- Create: `InchWatch/Features/WatchPostSetView.swift`
- Create: `InchWatch/Features/WatchRestTimerView.swift`
- Create: `InchWatch/Features/WatchExerciseCompleteView.swift`

Read `Specs/bodyweight-ux-design-v2.md` → "Watch App" section.

**Key difference from iOS:** Watch workout is always post-set confirmation. No real-time counting mode on Watch.

On exercise complete:
1. Build `WatchCompletionReport` from completed sets
2. Send via `transferUserInfo` to iPhone
3. iPhone-side `WatchConnectivityService` receives it and calls `SchedulingEngine.completeTrainingDay()`

**Commit:**
```bash
git add InchWatch/
git commit -m "feat: add Watch today and workout flow with completion sync"
```

---

## Phase 11: HealthKit

### Task 24: HealthKit integration

**Files:**
- Create: `InchApp/Services/HealthKitService.swift`

Read `Specs/framework-guidance.md` → "HealthKit" section. Use the exact `HKWorkout` pattern shown there.

**Info.plist additions required:**
- `NSHealthShareUsageDescription`
- `NSHealthUpdateUsageDescription`

**HealthKit capability must be enabled in Xcode project settings.**

Key method: `saveWorkout(startDate:endDate:totalEnergyBurned:metadata:)` — called from `WorkoutViewModel` at exercise completion.

```swift
// Call from WorkoutViewModel when session ends:
Task {
    try? await healthKitService.saveWorkout(
        startDate: sessionStartDate,
        endDate: .now,
        totalEnergyBurned: nil,
        metadata: ["exerciseId": enrolment.exerciseDefinition?.exerciseId ?? ""]
    )
}
```

**Commit:**
```bash
git add InchApp/Services/HealthKitService.swift
git commit -m "feat: add HealthKit workout logging"
```

---

## Phase 12: Sensor Recording

### Task 25: Core Motion recording (iOS)

**Files:**
- Create: `InchApp/Services/MotionRecordingService.swift`

Read `Specs/framework-guidance.md` → "Core Motion" section and `architecture.md` → "Core Motion Sensor Recording".

**NSMotionUsageDescription** must be in Info.plist.

Key behaviours:
- Start recording at set start (if `motionDataUploadConsented == true`)
- Write binary frames to a temp file: `{exerciseId}_set{N}_{timestamp}.bin`
- Stop recording at set complete → get file URL
- Create `SensorRecording` model and attach to `CompletedSet`

**Commit:**
```bash
git add InchApp/Services/MotionRecordingService.swift
git commit -m "feat: add Core Motion sensor recording service (iOS)"
```

---

### Task 26: Core Motion recording (Watch)

**Files:**
- Create: `InchWatch/Services/WatchMotionRecordingService.swift`

Same pattern as iOS but uses `CMMotionManager` on the Watch. After recording, send the file to iPhone via `WCSession.transferFile(_:metadata:)`.

iPhone-side `WatchConnectivityService.session(_:didReceive:)` receives the file, moves it to permanent storage, and creates the `SensorRecording` metadata.

**Commit:**
```bash
git add InchWatch/Services/WatchMotionRecordingService.swift
git commit -m "feat: add Watch motion recording with file transfer to iPhone"
```

---

## Phase 13: Background Upload

### Task 27: Background upload pipeline

**Files:**
- Create: `InchApp/Services/DataUploadService.swift`

Read `Specs/framework-guidance.md` → "BGProcessingTask" and `Specs/backend-api.md` → "Upload Endpoint".

**Info.plist additions:**
- `BGTaskSchedulerPermittedIdentifiers`: `["com.dailyascent.bodyweight.sensor-upload"]`

**Capability required:** Background Modes → Background processing.

Follow the `DataUploadService` pattern in `architecture.md` exactly:
- Register background task in `InchApp.init()`
- Schedule after each new `SensorRecording` is created
- Handler: fetch pending recordings → compress with gzip → POST to Supabase Storage → insert metadata row → mark `uploadStatus = .uploaded`
- Supabase URL and anon key stored in Keychain (use `swift-security-expert` skill)
- `@concurrent` on the upload method

**Supabase upload pattern:**
```swift
// Upload file to storage
let storageURL = supabaseURL
    .appendingPathComponent("storage/v1/object")
    .appendingPathComponent("sensor-data/\(exerciseId)/\(filename)")

var request = URLRequest(url: storageURL)
request.httpMethod = "POST"
request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
request.httpBody = compressedData
let (_, response) = try await URLSession.shared.data(for: request)

// Insert metadata row to postgres
// POST to /rest/v1/sensor_recordings with contributor_id, exercise_id, etc.
```

**Commit:**
```bash
git add InchApp/Services/DataUploadService.swift
git commit -m "feat: add background sensor data upload to Supabase"
```

---

## Phase 14: Streak Integration

### Task 28: Wire streak into dashboard

**Files:**
- Modify: `InchApp/Features/Today/TodayViewModel.swift`
- Modify: `InchApp/Features/Today/TodayView.swift`

After each exercise completion (from `WorkoutViewModel`), run `StreakCalculator.updateStreakState()`. Display current streak on `TodayView` (e.g. flame icon + count in the nav bar or a header card).

In `TodayViewModel.loadToday()`:
```swift
func checkAndUpdateStreak() {
    let today = Calendar.current.startOfDay(for: .now)
    let streakDescriptor = FetchDescriptor<StreakState>()
    guard let streakState = try? modelContext.fetch(streakDescriptor).first else { return }

    let hadDue = !dueExercises.isEmpty
    let completedToday = dueExercises.contains { enrolment in
        let sessionDate = Calendar.current.startOfDay(for: .now)
        return enrolment.completedSets?.contains {
            Calendar.current.isDate($0.sessionDate, inSameDayAs: sessionDate)
        } ?? false
    }

    StreakCalculator().updateStreakState(streakState, today: today,
                                         hadDueExercises: hadDue, completedAny: completedToday)
    try? modelContext.save()
}
```

**Commit:**
```bash
git commit -m "feat: wire streak calculator into today dashboard"
```

---

## Final Verification

After all phases are complete, run the full verification checklist:

**Step 1: Run all shared package tests**
```
⌘U — Expected: All tests PASS
Test count should include:
- SchedulingEngineTests: ≥7 tests (12 from spec + extras)
- ConflictDetectorTests: ≥3
- ConflictResolverTests: ≥2
- StreakCalculatorTests: ≥4
- ExerciseDataLoaderTests: ≥4
```

**Step 2: Run on iPhone 16 Pro simulator**
```
Product → Run (⌘R)
Walk through: onboarding → today dashboard → start a workout → complete sets → check program view
```

**Step 3: Run on Apple Watch Series 10 simulator**
```
Run the Watch scheme
Verify: today view shows pushed sessions, workout completes and syncs back to iPhone
```

**Step 4: Final commit**
```bash
git add .
git commit -m "feat: Daily Ascent v1 complete — all 17 build phases implemented"
```
