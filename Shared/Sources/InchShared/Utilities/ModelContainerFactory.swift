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
