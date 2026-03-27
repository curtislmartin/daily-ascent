import Foundation
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

    /// Deletes the on-disk SwiftData store and its WAL/SHM companions.
    /// Call this only when the store is known to be irrecoverably corrupt or incompatible.
    public static func deleteStore() {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let base = appSupport.appending(path: "default.store")
        for suffix in ["", "-wal", "-shm"] {
            let url = URL(fileURLWithPath: base.path + suffix)
            try? FileManager.default.removeItem(at: url)
        }
    }
}
