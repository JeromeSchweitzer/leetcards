import Foundation

/// The versioned top-level wrapper for `dataset.json`.
///
/// Keeping problems behind a `{ version, problems }` envelope (rather than a
/// bare array) lets the loader branch on `version` if a future breaking change
/// is ever needed, while additive changes stay backward/forward compatible.
struct Dataset: Codable, Sendable {
    let version: Int
    let generatedAt: String?
    let source: String?
    let problems: [Problem]

    enum CodingKeys: String, CodingKey {
        case version, source, problems
        case generatedAt = "generated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        generatedAt = try c.decodeIfPresent(String.self, forKey: .generatedAt)
        source = try c.decodeIfPresent(String.self, forKey: .source)
        problems = try c.decodeIfPresent([Problem].self, forKey: .problems) ?? []
    }

    init(version: Int = 1, generatedAt: String? = nil, source: String? = nil, problems: [Problem]) {
        self.version = version
        self.generatedAt = generatedAt
        self.source = source
        self.problems = problems
    }
}
