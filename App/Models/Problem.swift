import Foundation

/// A single flashcard problem, decoded from `dataset.json`.
///
/// Decoding is deliberately forward-compatible: only `id` and `title` are
/// required; every other field is optional with a sensible default, and unknown
/// JSON keys are ignored. That means a newer `dataset.json` can add fields
/// without breaking an older build of the app.
struct Problem: Codable, Identifiable, Hashable, Sendable {
    /// Stable LeetCode slug — used as the identity that progress keys off of.
    let id: String
    let title: String
    let number: Int?
    let order: Int?
    let difficulty: Difficulty?
    let description: String
    let coreIdea: String
    let tags: [String]
    let hints: [String]
    let leetcodeURL: URL?
    let solutions: [Solution]

    enum CodingKeys: String, CodingKey {
        case id, title, number, order, difficulty, description, tags, hints, solutions
        case coreIdea = "core_idea"
        case leetcodeURL = "leetcode_url"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        number = try c.decodeIfPresent(Int.self, forKey: .number)
        order = try c.decodeIfPresent(Int.self, forKey: .order)
        // Lenient: an unrecognized difficulty string decodes to nil, not an error.
        difficulty = (try c.decodeIfPresent(String.self, forKey: .difficulty)).flatMap(Difficulty.init(rawValue:))
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        coreIdea = try c.decodeIfPresent(String.self, forKey: .coreIdea) ?? ""
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        hints = try c.decodeIfPresent([String].self, forKey: .hints) ?? []
        leetcodeURL = try c.decodeIfPresent(URL.self, forKey: .leetcodeURL)
        solutions = try c.decodeIfPresent([Solution].self, forKey: .solutions) ?? []
    }

    /// Test/preview convenience initializer.
    init(
        id: String,
        title: String,
        number: Int? = nil,
        order: Int? = nil,
        difficulty: Difficulty? = nil,
        description: String = "",
        coreIdea: String = "",
        tags: [String] = [],
        hints: [String] = [],
        leetcodeURL: URL? = nil,
        solutions: [Solution] = []
    ) {
        self.id = id
        self.title = title
        self.number = number
        self.order = order
        self.difficulty = difficulty
        self.description = description
        self.coreIdea = coreIdea
        self.tags = tags
        self.hints = hints
        self.leetcodeURL = leetcodeURL
        self.solutions = solutions
    }
}

/// Difficulty decodes leniently from the dataset's capitalized strings; an
/// unrecognized value decodes to `nil` rather than throwing (forward-compat).
enum Difficulty: String, Codable, CaseIterable, Sendable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"
}

/// One tabbable code sample for a problem (from a scraped community solution).
struct Solution: Codable, Hashable, Identifiable, Sendable {
    let title: String?
    let language: String?
    let code: String

    var id: String { "\(title ?? "")|\(language ?? "")|\(code.prefix(24))" }

    /// Human-friendly label for the language tab.
    var languageLabel: String {
        switch language {
        case "cpp": "C++"
        case "csharp": "C#"
        case let lang?: lang.capitalized
        case nil: "Code"
        }
    }

    enum CodingKeys: String, CodingKey { case title, language, code }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        language = try c.decodeIfPresent(String.self, forKey: .language)
        code = try c.decodeIfPresent(String.self, forKey: .code) ?? ""
    }

    init(title: String?, language: String?, code: String) {
        self.title = title
        self.language = language
        self.code = code
    }
}
