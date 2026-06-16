import Foundation

/// Loads + decodes the dataset from a `DatasetProvider`.
///
/// Decoding is forward-compatible (see `Problem`/`Dataset`): unknown fields are
/// ignored and missing optional fields fall back to defaults, so a newer
/// `dataset.json` never crashes an older build. The decoder does not hard-fail
/// on a higher `version`; that decision is intentionally deferred to a future
/// breaking change, where the loader can branch on `Dataset.version`.
struct DatasetLoader {
    /// The newest schema version this build understands.
    static let supportedVersion = 1

    let provider: DatasetProvider

    init(provider: DatasetProvider = BundledDatasetSource()) {
        self.provider = provider
    }

    func load() throws -> Dataset {
        let data = try provider.loadData()
        do {
            return try JSONDecoder().decode(Dataset.self, from: data)
        } catch {
            throw DatasetError.decodingFailed(String(describing: error))
        }
    }
}
