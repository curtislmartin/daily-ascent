import SwiftData

enum BodyweightSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
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

enum BodyweightMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [BodyweightSchemaV1.self]
    }
    static var stages: [MigrationStage] { [] }
}
