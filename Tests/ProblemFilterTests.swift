import Foundation
import Testing
@testable import LeetCards

@Suite("Problem filtering")
struct ProblemFilterTests {

    private let problems = [
        Problem(id: "example-problem", title: "Example Problem", number: 1, order: 0, difficulty: .easy,
                tags: ["array", "hash-table"]),
        Problem(id: "example-b", title: "Example Problem B", number: 2, order: 1, difficulty: .medium,
                tags: ["linked-list", "math"]),
        Problem(id: "example-c", title: "Example Problem C", number: 4, order: 2, difficulty: .hard,
                tags: ["array", "binary-search"]),
    ]

    @Test("Empty criteria returns everything")
    func emptyReturnsAll() {
        #expect(filterProblems(problems, criteria: ProblemFilterCriteria()).count == 3)
    }

    @Test("Filter by difficulty")
    func byDifficulty() {
        let result = filterProblems(problems, criteria: .init(difficulties: [.easy, .hard]))
        #expect(Set(result.map(\.id)) == ["example-problem", "example-c"])
    }

    @Test("Filter by tag (overlap)")
    func byTag() {
        let result = filterProblems(problems, criteria: .init(tags: ["array"]))
        #expect(Set(result.map(\.id)) == ["example-problem", "example-c"])
    }

    @Test("Search matches title and number, case-insensitively")
    func bySearch() {
        #expect(filterProblems(problems, criteria: .init(searchText: "sum")).map(\.id) == ["example-problem"])
        #expect(filterProblems(problems, criteria: .init(searchText: "#4")).map(\.id) == ["example-c"])
        #expect(filterProblems(problems, criteria: .init(searchText: "MEDIAN")).map(\.id) == ["example-c"])
    }

    @Test("Criteria combine with AND")
    func combined() {
        // Easy AND tag linked-list: example-problem is easy but tagged array; none match.
        let none = filterProblems(problems, criteria: .init(difficulties: [.easy], tags: ["linked-list"]))
        #expect(none.isEmpty)

        // Search + difficulty + tag all satisfied only by example-c.
        let one = filterProblems(problems, criteria: .init(
            searchText: "example-c", difficulties: [.hard], tags: ["array"]
        ))
        #expect(one.map(\.id) == ["example-c"])
    }
}
