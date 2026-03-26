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

// V2 schema — adds variationName, targetDurationSeconds, timedPrepCountdownSeconds
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
