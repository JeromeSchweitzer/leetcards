import Foundation
import Testing
@testable import LeetCards

/// A provider that serves in-test JSON bytes instead of reading the bundle.
private struct InlineProvider: DatasetProvider {
    let json: String
    func loadData() throws -> Data { Data(json.utf8) }
}

@Suite("DatasetLoader")
struct DatasetLoaderTests {

    @Test("Decodes a well-formed versioned dataset")
    func decodesWellFormed() throws {
        let json = """
        {
          "version": 1,
          "generated_at": "2026-01-01T00:00:00Z",
          "source": "sample",
          "problems": [
            {
              "id": "sum-a-list", "number": 1, "order": 0, "title": "Sum a List",
              "difficulty": "Easy", "description": "desc", "core_idea": "running total",
              "tags": ["array"], "hints": ["h"],
              "leetcode_url": "https://example.com/problems/sum-a-list/",
              "solutions": [{"title": "x", "language": "python", "code": "print(1)"}]
            }
          ]
        }
        """
        let dataset = try DatasetLoader(provider: InlineProvider(json: json)).load()
        #expect(dataset.version == 1)
        #expect(dataset.problems.count == 1)
        let p = try #require(dataset.problems.first)
        #expect(p.id == "sum-a-list")
        #expect(p.difficulty == .easy)
        #expect(p.solutions.first?.language == "python")
    }

    @Test("Forward-compatible: ignores unknown fields and tolerates missing optionals")
    func forwardCompatible() throws {
        // Adds a future field ("spaced_repetition") the current build doesn't
        // know, and omits several optional fields entirely.
        let json = """
        {
          "version": 2,
          "spaced_repetition": {"interval": 3},
          "problems": [
            {
              "id": "x", "title": "X", "future_field": 99,
              "solutions": [{"code": "code only"}]
            }
          ]
        }
        """
        let dataset = try DatasetLoader(provider: InlineProvider(json: json)).load()
        let p = try #require(dataset.problems.first)
        #expect(p.id == "x")
        #expect(p.difficulty == nil)        // missing optional -> nil, not a crash
        #expect(p.tags.isEmpty)             // missing array -> default []
        #expect(p.coreIdea == "")           // missing string -> default ""
        #expect(p.solutions.first?.language == nil)
        #expect(p.solutions.first?.code == "code only")
    }

    @Test("Unrecognized difficulty decodes to nil rather than throwing")
    func lenientDifficulty() throws {
        let json = """
        { "version": 1, "problems": [
          {"id": "x", "title": "X", "difficulty": "Insane"}
        ] }
        """
        let dataset = try DatasetLoader(provider: InlineProvider(json: json)).load()
        #expect(dataset.problems.first?.difficulty == nil)
    }

    @Test("Invalid JSON surfaces a DatasetError instead of crashing")
    func invalidJSONThrows() {
        let provider = InlineProvider(json: "{ not valid json ]")
        #expect(throws: DatasetError.self) {
            try DatasetLoader(provider: provider).load()
        }
    }

    @Test("A missing bundle resource surfaces a DatasetError")
    func missingResourceThrows() {
        // A bundle that definitely has no dataset.json resource.
        let provider = BundledDatasetSource(resourceName: "does-not-exist", bundle: .main)
        #expect(throws: DatasetError.self) {
            try DatasetLoader(provider: provider).load()
        }
    }

    @Test("The bundled dataset loads (full dataset.json or sample) and is well-formed")
    func bundledDatasetLoads() throws {
        // Skips gracefully if no bundled dataset is reachable in this build context.
        let reachable = Bundle.datasetBundle.url(forResource: "dataset", withExtension: "json") != nil
            || Bundle.datasetBundle.url(forResource: "dataset.sample", withExtension: "json") != nil
        guard reachable else { return }
        let dataset = try DatasetLoader().load()
        #expect(dataset.problems.count >= 1)
        #expect(dataset.problems.allSatisfy { !$0.coreIdea.isEmpty })
    }
}
