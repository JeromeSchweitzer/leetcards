import Foundation
import SwiftData

/// Versioned SwiftData schema + migration plan.
///
/// V1 had only `Attempt`. V2 adds `DeckEntry` (curated deck membership) — an
/// additive change, so the migration is lightweight and the user's `Attempt`
/// history is preserved.
enum AppSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [Attempt.self] }
}

enum AppSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }
    static var models: [any PersistentModel.Type] { [Attempt.self, DeckEntry.self] }
}

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [AppSchemaV1.self, AppSchemaV2.self] }

    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: AppSchemaV1.self, toVersion: AppSchemaV2.self)]
    }
}

enum PersistenceStore {
    /// The model types in the current schema.
    static let models: [any PersistentModel.Type] = [Attempt.self, DeckEntry.self]

    /// The on-disk container the app uses.
    @MainActor
    static func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(models),
            migrationPlan: AppMigrationPlan.self
        )
    }

    /// An in-memory container for tests and previews.
    @MainActor
    static func makeInMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
