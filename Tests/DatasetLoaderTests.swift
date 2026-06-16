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
          "generated_at": "2026-06-04T00:00:00Z",
          "source": "sample",
          "problems": [
            {
              "id": "example-problem", "number": 1, "order": 0, "title": "Example Problem",
              "difficulty": "Easy", "description": "desc", "core_idea": "hash map",
              "tags": ["array"], "hints": ["h"],
              "leetcode_url": "https://example.com/problems/example-problem/",
              "solutions": [{"title": "x", "language": "python", "code": "print(1)"}]
            }
          ]
        }
        """
        let dataset = try DatasetLoader(provider: InlineProvider(json: json)).load()
        #expect(dataset.version == 1)
        #expect(dataset.problems.count == 1)
        let p = try #require(dataset.problems.first)
        #expect(p.id == "example-problem")
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

    @Test("The bundled dataset.json loads and is non-trivial")
    func bundledDatasetLoads() throws {
        // Skips gracefully if the resource isn't reachable in this build context.
        guard Bundle.datasetBundle.url(forResource: "dataset", withExtension: "json") != nil else { return }
        let dataset = try DatasetLoader().load()
        #expect(dataset.problems.count > 100)
        #expect(dataset.problems.allSatisfy { !$0.coreIdea.isEmpty })
    }
}
