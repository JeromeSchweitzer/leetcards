import Foundation

/// Abstraction over *where* the dataset bytes come from.
///
/// Today the only implementation reads the bundled `dataset.json`. A future
/// `RemoteDatasetSource` could download a newer dataset into Application Support
/// and fall back to the bundle — without any change to `DatasetLoader`, the
/// stores, or the views.
protocol DatasetProvider: Sendable {
    func loadData() throws -> Data
}

/// Reads the bundled dataset, trying each candidate resource name in order.
///
/// The full `dataset.json` is gitignored (it bundles only when present locally);
/// the committed `dataset.sample.json` is the public fallback so a fresh clone
/// still builds and runs.
struct BundledDatasetSource: DatasetProvider {
    let resourceNames: [String]
    let bundle: Bundle

    init(resourceNames: [String] = ["dataset", "dataset.sample"], bundle: Bundle = .datasetBundle) {
        self.resourceNames = resourceNames
        self.bundle = bundle
    }

    /// Single-name convenience (used by tests).
    init(resourceName: String, bundle: Bundle = .datasetBundle) {
        self.resourceNames = [resourceName]
        self.bundle = bundle
    }

    func loadData() throws -> Data {
        for name in resourceNames {
            if let url = bundle.url(forResource: name, withExtension: "json") {
                return try Data(contentsOf: url)
            }
        }
        throw DatasetError.missingResource(resourceNames.joined(separator: " / "))
    }
}

extension Bundle {
    /// The bundle that carries `dataset.json`. SwiftPM places it in the module
    /// resource bundle (`Bundle.module`); the Xcode app build ships it in the
    /// main app bundle (`Bundle.main`).
    static var datasetBundle: Bundle {
        #if SWIFTPM
        .module
        #else
        .main
        #endif
    }
}

enum DatasetError: Error, LocalizedError {
    case missingResource(String)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingResource(let name):
            "Couldn't find \(name).json in the app bundle."
        case .decodingFailed(let detail):
            "The dataset couldn't be read: \(detail)"
        }
    }
}
