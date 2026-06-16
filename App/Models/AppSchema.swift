import Foundation
import SwiftData

/// Versioned SwiftData schema + migration plan.
///
/// Today there is a single version, but routing the `ModelContainer` through a
/// `SchemaMigrationPlan` now means future changes to `Attempt` (e.g. adding
/// spaced-repetition scheduling fields) can ship a lightweight or custom
/// migration stage without wiping the user's history.
enum AppSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [Attempt.self] }
}

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [AppSchemaV1.self] }

    /// No migrations yet — add `MigrationStage`s here when a V2 schema lands.
    static var stages: [MigrationStage] { [] }
}

enum PersistenceStore {
    /// The on-disk container the app uses.
    @MainActor
    static func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Attempt.self,
            migrationPlan: AppMigrationPlan.self
        )
    }

    /// An in-memory container for tests and previews.
    @MainActor
    static func makeInMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Attempt.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
