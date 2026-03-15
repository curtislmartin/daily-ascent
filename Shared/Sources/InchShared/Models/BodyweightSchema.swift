import SwiftData

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

public enum BodyweightMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [BodyweightSchemaV1.self]
    }
    public static var stages: [MigrationStage] { [] }
}
