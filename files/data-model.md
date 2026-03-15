# SwiftData Schema

> **Design constraints applied from SwiftData Pro skill:**
> - CloudKit-ready: no `@Attribute(.unique)` or `#Unique`, all properties have defaults or are optional, all relationships optional
> - Explicit delete rules and inverse relationships on every `@Relationship`
> - `#Index` on frequently queried date properties (iOS 18+)
> - Enum properties conform to `Codable`
> - Model instances never cross actor boundaries — use `PersistentIdentifier` for WatchConnectivity
> - Migration schema from v1 even if only lightweight migrations are expected
> - No property named `description` on any `@Model` class

---

## Static Data (loaded from exercise-data.json at first launch)

These entities represent the exercise program definitions. They are seeded from the bundled JSON and never modified by the user.

### ExerciseDefinition

The top-level exercise type. 6 instances seeded from JSON.

```swift
@Model
final class ExerciseDefinition {
    var exerciseId: String = ""           // "push_ups", "squats", etc.
    var name: String = ""                 // "Push-Ups"
    var muscleGroup: MuscleGroup = .upperPush
    var color: String = ""                // "#E8722A"
    var countingMode: CountingMode = .postSetConfirmation
    var defaultRestSeconds: Int = 60
    var sortOrder: Int = 0                // for display ordering

    @Relationship(deleteRule: .cascade, inverse: \LevelDefinition.exercise)
    var levels: [LevelDefinition]? = []

    // Inverse from enrolment
    @Relationship(deleteRule: .nullify, inverse: \ExerciseEnrolment.exerciseDefinition)
    var enrolments: [ExerciseEnrolment]? = []
}
```

### LevelDefinition

Level configuration within an exercise. 3 per exercise (18 total).

```swift
@Model
final class LevelDefinition {
    var level: Int = 1                            // 1, 2, or 3
    var restDayPattern: [Int] = [2, 2, 3]         // gap pattern between training days
    var testTarget: Int = 0                        // reps needed to pass the test
    var extraRestBeforeTest: Int? = nil             // extra gap before test day (e.g. 4 for push-ups L2)
    var totalDays: Int = 0                         // total training days including test

    var exercise: ExerciseDefinition?

    @Relationship(deleteRule: .cascade, inverse: \DayPrescription.level)
    var days: [DayPrescription]? = []
}
```

### DayPrescription

A single training day's set/rep prescription. ~300 total across all exercises.

```swift
@Model
final class DayPrescription {
    var dayNumber: Int = 0                // day within level (1-indexed)
    var sets: [Int] = []                  // rep targets per set, e.g. [34, 24, 22, 20, 18]
    var isTest: Bool = false              // true for the final day of each level

    var level: LevelDefinition?

    // Computed (not stored)
    var totalReps: Int { sets.reduce(0, +) }
    var setCount: Int { sets.count }
}
```

---

## User State (created and modified during use)

### ExerciseEnrolment

Tracks which exercises the user has enrolled in and their current progress. One per enrolled exercise.

```swift
@Model
final class ExerciseEnrolment {
    #Index<ExerciseEnrolment>([\.nextScheduledDate])

    var enrolledAt: Date = Date.now
    var isActive: Bool = true              // false if user unenrolled (archived)

    // Current progress
    var currentLevel: Int = 1
    var currentDay: Int = 1                // day within current level
    var lastCompletedDate: Date? = nil
    var nextScheduledDate: Date? = nil     // computed and stored for query efficiency

    // Scheduling state
    var restPatternIndex: Int = 0          // position within the rest day pattern cycle

    var exerciseDefinition: ExerciseDefinition?

    @Relationship(deleteRule: .cascade, inverse: \CompletedSet.enrolment)
    var completedSets: [CompletedSet]? = []
}
```

### CompletedSet

A single completed set within a training session. This is the atomic unit of workout data.

```swift
@Model
final class CompletedSet {
    #Index<CompletedSet>([\.completedAt])

    var completedAt: Date = Date.now
    var sessionDate: Date = Date.now       // the calendar date of the training day
    var exerciseId: String = ""            // denormalised for query convenience
    var level: Int = 0
    var dayNumber: Int = 0
    var setNumber: Int = 0                 // 1-indexed within the session
    var targetReps: Int = 0
    var actualReps: Int = 0
    var isTest: Bool = false
    var testPassed: Bool? = nil            // nil for non-test sets

    // Counting metadata
    var countingMode: CountingMode = .postSetConfirmation
    var setDurationSeconds: Double? = nil  // elapsed time for the set (for post-set confirmation mode)

    var enrolment: ExerciseEnrolment?

    @Relationship(deleteRule: .cascade, inverse: \SensorRecording.completedSet)
    var sensorRecordings: [SensorRecording]? = []
}
```

### SensorRecording

Metadata for a motion data file recorded during a set. The actual sensor data is stored as a file on disk (not in SwiftData).

```swift
@Model
final class SensorRecording {
    var recordedAt: Date = Date.now
    var device: SensorDevice = .iPhone     // which device recorded this
    var exerciseId: String = ""
    var level: Int = 0
    var dayNumber: Int = 0
    var setNumber: Int = 0
    var confirmedReps: Int = 0             // the label for ML training
    var sampleRateHz: Int = 100
    var durationSeconds: Double = 0
    var filePath: String = ""              // relative path to the sensor data file
    var fileSizeBytes: Int = 0

    // Upload state
    var uploadStatus: UploadStatus = .pending
    var uploadedAt: Date? = nil

    var completedSet: CompletedSet?
}
```

---

## User Settings & Consent

### UserSettings

Singleton — one instance per app install. Stores all user preferences.

```swift
@Model
final class UserSettings {
    var createdAt: Date = Date.now

    // Rest timer overrides (nil = use exercise default)
    var restOverrides: [String: Int] = [:]    // exerciseId -> seconds

    // Counting mode overrides (nil = use exercise default)
    var countingModeOverrides: [String: String] = [:]  // exerciseId -> "real_time" or "post_set_confirmation"

    // Inter-exercise rest
    var interExerciseRestEnabled: Bool = false
    var interExerciseRestSeconds: Int = 120

    // Notifications
    var dailyReminderEnabled: Bool = true
    var dailyReminderHour: Int = 8
    var dailyReminderMinute: Int = 0
    var streakProtectionEnabled: Bool = true
    var testDayNotificationEnabled: Bool = true
    var levelUnlockNotificationEnabled: Bool = true

    // Data consent
    var motionDataUploadConsented: Bool = false
    var consentDate: Date? = nil
    var contributorId: String = ""         // anonymous UUID for ML data

    // Optional demographics (only if consented to upload)
    var ageRange: String? = nil            // "under_18", "18_29", "30_39", etc.
    var heightRange: String? = nil         // "short", "medium", "tall"
    var biologicalSex: String? = nil       // "male", "female", "prefer_not_to_say"
    var activityLevel: String? = nil       // "beginner", "intermediate", "advanced"
}
```

### StreakState

Singleton — tracks the current streak.

```swift
@Model
final class StreakState {
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastActiveDate: Date? = nil        // last date where at least one due exercise was completed
}
```

---

## Future Entities (schema reserved, not implemented in v1)

### UserEntitlement

```swift
@Model
final class UserEntitlement {
    var productId: String = ""
    var purchaseDate: Date = Date.now
    var expiresDate: Date? = nil
    var transactionId: String = ""
}
```

---

## Enums

All enums used in `@Model` classes must conform to `Codable` and `Sendable`.

```swift
enum MuscleGroup: String, Codable, Sendable, CaseIterable {
    case upperPush = "upper_push"
    case upperPull = "upper_pull"
    case lower = "lower"
    case lowerPosterior = "lower_posterior"
    case coreFlexion = "core_flexion"
    case coreStability = "core_stability"

    /// Muscle groups that conflict with each other for test day isolation
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
    case pending          // recorded, not yet uploaded
    case uploading        // currently transferring
    case uploaded         // successfully uploaded
    case failed           // upload failed, will retry
    case localOnly        // user declined upload consent
}
```

---

## Model Container Configuration

```swift
import SwiftData

let schema = Schema([
    ExerciseDefinition.self,
    LevelDefinition.self,
    DayPrescription.self,
    ExerciseEnrolment.self,
    CompletedSet.self,
    SensorRecording.self,
    UserSettings.self,
    StreakState.self,
    UserEntitlement.self,
])

let modelConfiguration = ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: false,
    // CloudKit container name reserved for future use
    // cloudKitDatabase: .private("iCloud.com.inch.bodyweight")
)
```

---

## Key Queries the Schema Must Support Efficiently

1. **"What's due today?"** — Fetch all active `ExerciseEnrolment` where `nextScheduledDate <= today`. Indexed on `nextScheduledDate`.

2. **"What are the prescribed sets for this exercise today?"** — Navigate from `ExerciseEnrolment` → `exerciseDefinition` → `levels` (filter by `currentLevel`) → `days` (filter by `currentDay`).

3. **"Has this exercise been completed today?"** — Fetch `CompletedSet` where `sessionDate == today` and `exerciseId == X`. Indexed on `completedAt`.

4. **"Show workout history"** — Fetch all `CompletedSet` ordered by `completedAt` descending.

5. **"How many total reps for this exercise?"** — Aggregate `actualReps` from `CompletedSet` filtered by `exerciseId`.

6. **"What sensor recordings need uploading?"** — Fetch `SensorRecording` where `uploadStatus == .pending`.

---

## Migration Schema

Even for v1, register an explicit migration plan:

```swift
enum BodyweightSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [ExerciseDefinition.self, LevelDefinition.self, DayPrescription.self,
         ExerciseEnrolment.self, CompletedSet.self, SensorRecording.self,
         UserSettings.self, StreakState.self, UserEntitlement.self]
    }
}

enum BodyweightMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [BodyweightSchemaV1.self]
    }
    static var stages: [MigrationStage] { [] }
}
```

---

## WatchConnectivity Data Transfer

Model instances cannot cross actor boundaries. When syncing to/from the Watch, transfer lightweight dictionaries and re-fetch or create models on the receiving side.

**iPhone → Watch (schedule data):**
```swift
// Serialise to dictionary, NOT model objects
struct WatchSession: Codable, Sendable {
    let exerciseId: String
    let exerciseName: String
    let color: String
    let level: Int
    let dayNumber: Int
    let sets: [Int]
    let isTest: Bool
    let testTarget: Int?
    let restSeconds: Int
    let countingMode: String
}
```

**Watch → iPhone (completion data):**
```swift
struct WatchCompletionReport: Codable, Sendable {
    let exerciseId: String
    let level: Int
    let dayNumber: Int
    let completedSets: [WatchSetResult]
    let completedAt: Date
}

struct WatchSetResult: Codable, Sendable {
    let setNumber: Int
    let targetReps: Int
    let actualReps: Int
    let durationSeconds: Double?
}
```

These are plain `Codable` structs, not SwiftData models. The receiving side creates the appropriate `@Model` instances in its own `ModelContext`.
