import Foundation
import Testing
@testable import LeetCards

@Suite("Problem filtering")
struct ProblemFilterTests {

    private let problems = [
        Problem(id: "sum-a-list", title: "Sum a List", number: 1, order: 0, difficulty: .easy,
                tags: ["array", "iteration"]),
        Problem(id: "reverse-a-string", title: "Reverse a String", number: 2, order: 1, difficulty: .medium,
                tags: ["string", "two-pointers"]),
        Problem(id: "binary-search", title: "Binary Search", number: 4, order: 2, difficulty: .hard,
                tags: ["array", "binary-search"]),
    ]

    @Test("Empty criteria returns everything")
    func emptyReturnsAll() {
        #expect(filterProblems(problems, criteria: ProblemFilterCriteria()).count == 3)
    }

    @Test("Filter by difficulty")
    func byDifficulty() {
        let result = filterProblems(problems, criteria: .init(difficulties: [.easy, .hard]))
        #expect(Set(result.map(\.id)) == ["sum-a-list", "binary-search"])
    }

    @Test("Filter by tag (overlap)")
    func byTag() {
        let result = filterProblems(problems, criteria: .init(tags: ["array"]))
        #expect(Set(result.map(\.id)) == ["sum-a-list", "binary-search"])
    }

    @Test("Search matches title and number, case-insensitively")
    func bySearch() {
        #expect(filterProblems(problems, criteria: .init(searchText: "sum")).map(\.id) == ["sum-a-list"])
        #expect(filterProblems(problems, criteria: .init(searchText: "#4")).map(\.id) == ["binary-search"])
        #expect(filterProblems(problems, criteria: .init(searchText: "BINARY")).map(\.id) == ["binary-search"])
    }

    @Test("Criteria combine with AND")
    func combined() {
        // Easy AND tag string: sum-a-list is easy but tagged array; none match.
        let none = filterProblems(problems, criteria: .init(difficulties: [.easy], tags: ["string"]))
        #expect(none.isEmpty)

        // Search + difficulty + tag all satisfied only by binary-search.
        let one = filterProblems(problems, criteria: .init(
            searchText: "binary", difficulties: [.hard], tags: ["array"]
        ))
        #expect(one.map(\.id) == ["binary-search"])
    }
}
