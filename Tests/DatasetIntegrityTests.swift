import Foundation
import Testing
@testable import LeetCards

/// Guards the shape/quality of whatever dataset is bundled — the full local
/// dataset.json when present, otherwise the committed dataset.sample.json — so a
/// bad/edited dataset fails fast. (The size isn't asserted, since the public
/// repo ships only the small sample.)
@Suite("Bundled dataset integrity")
struct DatasetIntegrityTests {

    private func loadBundled() throws -> Dataset? {
        let reachable = Bundle.datasetBundle.url(forResource: "dataset", withExtension: "json") != nil
            || Bundle.datasetBundle.url(forResource: "dataset.sample", withExtension: "json") != nil
        guard reachable else { return nil }  // not reachable in this build context — skip
        return try DatasetLoader().load()
    }

    @Test("Bundled dataset is non-empty")
    func count() throws {
        guard let dataset = try loadBundled() else { return }
        #expect(dataset.problems.count >= 1)
    }

    @Test("Every problem has the fields the UI relies on")
    func requiredFields() throws {
        guard let dataset = try loadBundled() else { return }
        for p in dataset.problems {
            #expect(!p.id.isEmpty)
            #expect(!p.title.isEmpty)
            #expect(!p.coreIdea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "empty core_idea: \(p.id)")
            #expect(!p.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "empty description: \(p.id)")
            #expect(p.difficulty != nil, "unknown difficulty: \(p.id)")
        }
    }

    @Test("Every problem has at least one solution with non-empty code")
    func solutionsHaveCode() throws {
        guard let dataset = try loadBundled() else { return }
        for p in dataset.problems {
            #expect(!p.solutions.isEmpty, "no solutions: \(p.id)")
            #expect(p.solutions.allSatisfy { !$0.code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
                    "a solution had empty code: \(p.id)")
        }
    }

    @Test("Ids are unique and order is 0..<count")
    func idsAndOrder() throws {
        guard let dataset = try loadBundled() else { return }
        let ids = dataset.problems.map(\.id)
        #expect(Set(ids).count == ids.count, "duplicate ids present")
        #expect(dataset.problems.map { $0.order ?? -1 } == Array(0..<dataset.problems.count))
    }
}
