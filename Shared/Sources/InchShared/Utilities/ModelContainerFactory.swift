import Foundation
import SwiftData

public enum ModelContainerFactory {
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(BodyweightSchemaV2.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        // No explicit migration plan — SwiftData infers lightweight migration automatically.
        // An explicit plan would require V1/V2 snapshots with distinct fingerprints, which
        // we don't have since both reference the same current model classes.
        return try ModelContainer(for: schema, configurations: [config])
    }

}
