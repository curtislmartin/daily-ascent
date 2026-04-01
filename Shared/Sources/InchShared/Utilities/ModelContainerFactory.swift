import Foundation
import SwiftData

public enum ModelContainerFactory {
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(BodyweightSchemaV3.models)
        let cloudKitDatabase: ModelConfiguration.CloudKitDatabase = inMemory ? .none : .private("iCloud.dev.clmartin.inch")
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: cloudKitDatabase
        )
        return try ModelContainer(
            for: schema,
            configurations: [config]
        )
    }

}
