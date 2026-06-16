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

/// Reads `dataset.json` from the app bundle.
struct BundledDatasetSource: DatasetProvider {
    let resourceName: String
    let bundle: Bundle

    init(resourceName: String = "dataset", bundle: Bundle = .datasetBundle) {
        self.resourceName = resourceName
        self.bundle = bundle
    }

    func loadData() throws -> Data {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw DatasetError.missingResource(resourceName)
        }
        return try Data(contentsOf: url)
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
