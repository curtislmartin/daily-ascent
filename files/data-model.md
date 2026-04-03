# SwiftData Schema

> Last updated: 2026-04-03

## Design Constraints

- CloudKit-ready: no `@Attribute(.unique)` or `#Unique`, all properties have defaults or are optional, all relationships optional
- Explicit delete rules and inverse relationships on every `@Relationship`
- `#Index` on frequently queried date properties (iOS 18+)
- Enum properties conform to `Codable`
- Model instances never cross actor boundaries — use `PersistentIdentifier` for WatchConnectivity
- Migration schema maintained across versions (currently V1 → V2 → V3)
- No property named `description` on any `@Model` class

---

## Static Data (loaded from exercise-data.json at first launch)

These entities represent the exercise program definitions. Seeded from the bundled JSON at first launch and never modified by the user.

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
    var sortOrder: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \LevelDefinition.exercise)
    var levels: [LevelDefinition]? = []

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
    var extraRestBeforeTest: Int? = nil             // extra gap before test day
    var totalDays: Int = 0                         // total training days including test day
    var variationName: String? = nil               // optional label for level variants (e.g. "Assisted")

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

Tracks the user's enrolment in a single exercise and all current progress. One per enrolled exercise.

```swift
@Model
final class ExerciseEnrolment {
    #Index<ExerciseEnrolment>([\.nextScheduledDate])

    var enrolledAt: Date = Date.now
    var isActive: Bool = true              // false if user has unenrolled (archived)

    // Current progress
    var currentLevel: Int = 1
    var currentDay: Int = 1                // day within current level
    var lastCompletedDate: Date? = nil
    var nextScheduledDate: Date? = nil     // computed and stored for query efficiency

    // Scheduling state
    var restPatternIndex: Int = 0          // position within the rest day pattern cycle

    // Adaptive difficulty
    var recentDifficultyRatings: [String] = []   // DifficultyRating raw values, last N sessions
    var recentCompletionRatios: [Double] = []    // completion ratio per session, last N sessions
    var needsRepeat: Bool = false                // true: AdaptationEngine decided to repeat this day
    var isRepeatSession: Bool = false            // true during an active repeat session
    var sessionPrescriptionOverride: Double? = nil  // multiplier applied to rep targets this session

    var exerciseDefinition: ExerciseDefinition?

    @Relationship(deleteRule: .cascade, inverse: \CompletedSet.enrolment)
    var completedSets: [CompletedSet]? = []
}
```

### CompletedSet

A single completed set within a training session. The atomic unit of workout data and the recovery anchor for session resume.

```swift
@Model
final class CompletedSet {
    #Index<CompletedSet>([\.completedAt])

    var completedAt: Date = Date.now
    var sessionDate: Date = Date.now       // calendar date of the training day (used for filtering)
    var exerciseId: String = ""            // denormalised for query convenience
    var level: Int = 0
    var dayNumber: Int = 0
    var setNumber: Int = 0                 // 1-indexed within the session
    var targetReps: Int = 0
    var actualReps: Int = 0                // 0 for timed sets (see targetDurationSeconds)
    var isTest: Bool = false
    var testPassed: Bool? = nil            // nil for non-test sets

    // Counting metadata
    var countingMode: CountingMode = .postSetConfirmation
    var setDurationSeconds: Double? = nil          // elapsed hold duration (timed mode)
    var targetDurationSeconds: Int? = nil          // prescribed hold duration (nil for rep-based sets)

    var enrolment: ExerciseEnrolment?

    @Relationship(deleteRule: .cascade, inverse: \SensorRecording.completedSet)
    var sensorRecordings: [SensorRecording]? = []
}
```

### SensorRecording

Metadata for a motion data file recorded during a set. The actual sensor data is stored as a binary file on disk (not in SwiftData).

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
    var sessionId: String = ""             // UUID linking all sets recorded in one workout session
    var countingMode: String = ""          // CountingMode raw value at time of recording

    // Upload state
    var uploadStatus: UploadStatus = .pending
    var uploadedAt: Date? = nil

    var completedSet: CompletedSet?
}
```

### Achievement

A record of an achievement the user has unlocked. Persisted immediately on unlock; `wasCelebrated` is set to `true` after the in-app toast is shown.

```swift
@Model
final class Achievement {
    var id: String = ""                // unique achievement identifier, e.g. "streak_7"
    var category: String = ""          // "streak", "level", "exercise", etc.
    var unlockedAt: Date = Date.now
    var exerciseId: String? = nil      // set for exercise-specific achievements
    var numericValue: Int? = nil       // e.g. streak count at unlock
    var wasCelebrated: Bool = false    // true after the celebration toast has been shown
    var sessionDate: Date? = nil       // calendar date the achievement was earned
}
```

---

## User Settings & Consent

### UserSettings

Singleton — one instance per app install. Stores all user preferences and consent state.

```swift
@Model
final class UserSettings {
    var createdAt: Date = Date.now

    // Rest timer overrides (nil = use exercise default)
    var restOverrides: [String: Int] = [:]             // exerciseId -> seconds

    // Counting mode overrides
    var countingModeOverrides: [String: String] = [:]  // exerciseId -> CountingMode raw value

    // Inter-exercise rest
    var interExerciseRestEnabled: Bool = false
    var interExerciseRestSeconds: Int = 120

    // Notifications
    var dailyReminderEnabled: Bool = true
    var dailyReminderHour: Int = 8
    var dailyReminderMinute: Int = 0
    var streakProtectionEnabled: Bool = true
    var streakProtectionHour: Int = 19              // hour for streak protection reminder
    var streakProtectionMinute: Int = 0
    var testDayNotificationEnabled: Bool = true
    var levelUnlockNotificationEnabled: Bool = true
    var achievementNotificationEnabled: Bool = true

    // Display
    var showConflictWarnings: Bool = true
    var appearanceMode: String = "system"           // "system", "light", "dark"

    // Recording
    var dualDeviceRecordingEnabled: Bool = true     // record on both iPhone and Watch simultaneously
    var timedPrepCountdownSeconds: Int = 5          // countdown before timed holds begin

    // Data consent
    var motionDataUploadConsented: Bool = false
    var consentDate: Date? = nil

    // Demographics (only collected when motion upload consented)
    var ageRange: String? = nil            // "under_18", "18_29", "30_39", etc.
    var heightRange: String? = nil         // "short", "medium", "tall"
    var biologicalSex: String? = nil       // "male", "female", "prefer_not_to_say"
    var activityLevel: String? = nil       // "beginner", "intermediate", "advanced"

    // Computed convenience (not stored)
    var hasDemographics: Bool {
        ageRange != nil && heightRange != nil &&
        biologicalSex != nil && activityLevel != nil
    }

    // Onboarding state
    var onboardingComplete: Bool = false
    var isFirstLaunch: Bool = true
    var seenExerciseInfo: [String] = []    // exerciseIds where the info sheet has been dismissed

    // Analytics
    var analyticsEnabled: Bool = true
}
```

### StreakState

Singleton — tracks the current training streak.

```swift
@Model
final class StreakState {
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastActiveDate: Date? = nil        // last date where at least one due exercise was completed
    var lastDueDate: Date? = nil           // last date exercises were due (distinguishes rest days from skipped days)
    var previousLastDueDate: Date? = nil   // lastDueDate before it was advanced to today; used by StreakCalculator
                                           // so consecutive-day detection still works once today's session completes
}
```

---

## Entitlements

### UserEntitlement

Records in-app purchases and subscriptions. Present in schema from V1 for future use.

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

All enums used in `@Model` classes conform to `Codable` and `Sendable`.

```swift
enum MuscleGroup: String, Codable, Sendable, CaseIterable {
    case upperPush = "upper_push"
    case upperPull = "upper_pull"
    case lower = "lower"
    case lowerPosterior = "lower_posterior"
    case coreFlexion = "core_flexion"
    case coreStability = "core_stability"

    /// Muscle groups that conflict with each other for scheduling purposes
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
    case realTime = "real_time"                    // motion-assisted, user taps to count
    case postSetConfirmation = "post_set_confirmation"  // user enters reps after the set
    case timed = "timed"                           // hold for a prescribed duration
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
    case localOnly        // user has not granted upload consent
}

// Not stored in SwiftData — used by AdaptationEngine and ExerciseEnrolment.recentDifficultyRatings
enum DifficultyRating: String, CaseIterable, Sendable {
    case tooEasy   = "too_easy"
    case justRight = "just_right"
    case tooHard   = "too_hard"
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
    Achievement.self,
    UserEntitlement.self,
])

let modelConfiguration = ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: false,
    // CloudKit container reserved for future use
    // cloudKitDatabase: .private("iCloud.com.dailyascent.bodyweight")
)
```

---

## Key Queries

1. **"What's due today?"** — Fetch all active `ExerciseEnrolment` where `nextScheduledDate <= today`. Indexed on `nextScheduledDate`.

2. **"What's the prescription for this exercise today?"** — Navigate from `ExerciseEnrolment` → `exerciseDefinition` → `levels` (filter by `currentLevel`) → `days` (filter by `currentDay`).

3. **"Has this exercise been completed today?"** — Fetch `CompletedSet` where `sessionDate >= todayStart` and `exerciseId == X`. Indexed on `completedAt`.

4. **"Can this workout be resumed?"** — Fetch `CompletedSet` where `sessionDate >= todayStart` and `exerciseId == X`; compare count against prescription set count.

5. **"Show workout history"** — Fetch all `CompletedSet` ordered by `completedAt` descending.

6. **"What sensor recordings need uploading?"** — Fetch `SensorRecording` where `uploadStatus == .pending`.

7. **"Has this achievement already been unlocked?"** — Fetch `Achievement` where `id == X`.

---

## Migration Schema

Three versions to date. All migrations are lightweight (new fields with defaults only, no data transforms).

```swift
// V1 — initial release schema
enum BodyweightSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [ExerciseDefinition.self, LevelDefinition.self, DayPrescription.self,
         ExerciseEnrolment.self, CompletedSet.self, SensorRecording.self,
         UserSettings.self, StreakState.self, UserEntitlement.self]
    }
}

// V2 — adds targetDurationSeconds (CompletedSet), timedPrepCountdownSeconds (UserSettings)
enum BodyweightSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [ExerciseDefinition.self, LevelDefinition.self, DayPrescription.self,
         ExerciseEnrolment.self, CompletedSet.self, SensorRecording.self,
         UserSettings.self, StreakState.self, UserEntitlement.self]
    }
}

// V3 — adds adaptive difficulty fields (ExerciseEnrolment), seenExerciseInfo/isFirstLaunch/
//       analyticsEnabled/achievementNotificationEnabled (UserSettings), Achievement model
enum BodyweightSchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)
    static var models: [any PersistentModel.Type] {
        [ExerciseDefinition.self, LevelDefinition.self, DayPrescription.self,
         ExerciseEnrolment.self, CompletedSet.self, SensorRecording.self,
         UserSettings.self, StreakState.self, UserEntitlement.self, Achievement.self]
    }
}

enum BodyweightMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [BodyweightSchemaV1.self, BodyweightSchemaV2.self, BodyweightSchemaV3.self]
    }
    static var stages: [MigrationStage] { [migrateV1toV2, migrateV2toV3] }

    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: BodyweightSchemaV1.self,
        toVersion: BodyweightSchemaV2.self
    )
    static let migrateV2toV3 = MigrationStage.lightweight(
        fromVersion: BodyweightSchemaV2.self,
        toVersion: BodyweightSchemaV3.self
    )
}
```

---

## WatchConnectivity Data Transfer

Model instances cannot cross actor boundaries. When syncing to/from the Watch, transfer lightweight `Codable` structs and re-fetch or create models on the receiving side.

**iPhone → Watch (schedule data):**
```swift
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
