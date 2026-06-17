import Foundation

/// Filter criteria for the problem browser. Empty fields impose no constraint.
struct ProblemFilterCriteria: Equatable, Sendable {
    var searchText: String = ""
    var difficulties: Set<Difficulty> = []
    var tags: Set<String> = []

    var isEmpty: Bool {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && difficulties.isEmpty && tags.isEmpty
    }
}

/// Pure filter: difficulty AND tag-overlap AND text-match. Kept out of the view
/// so it can be unit-tested directly.
func filterProblems(_ problems: [Problem], criteria: ProblemFilterCriteria) -> [Problem] {
    let query = criteria.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return problems.filter { problem in
        if !criteria.difficulties.isEmpty {
            guard let difficulty = problem.difficulty, criteria.difficulties.contains(difficulty) else {
                return false
            }
        }
        if !criteria.tags.isEmpty {
            guard !criteria.tags.isDisjoint(with: Set(problem.tags)) else { return false }
        }
        if !query.isEmpty {
            let haystack = "\(problem.number.map { "#\($0) " } ?? "")\(problem.title)".lowercased()
            guard haystack.contains(query) else { return false }
        }
        return true
    }
}
