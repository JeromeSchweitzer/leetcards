import Foundation
import Observation
import SwiftData

/// The deck's state: which problems are in play (per `DeckQuery`), where we are
/// in them, and the bridge to grading + persistence.
///
/// Built around a `DeckQuery` so order/filter changes (shuffle, sequential,
/// review-failed) just call `rebuild()` rather than introducing new code paths.
@MainActor
@Observable
final class DeckStore {
    private let allProblems: [Problem]
    private let context: ModelContext
    let grader: any Grading

    /// The problems currently in the deck, after filter + order are applied.
    private(set) var deck: [Problem] = []
    /// Index of the current card within `deck`.
    var index: Int = 0

    var query: DeckQuery {
        didSet { rebuild() }
    }

    init(
        problems: [Problem],
        context: ModelContext,
        grader: any Grading,
        query: DeckQuery = DeckQuery()
    ) {
        self.allProblems = problems
        self.context = context
        self.grader = grader
        self.query = query
        rebuild()
    }

    // MARK: - Navigation

    var current: Problem? {
        deck.indices.contains(index) ? deck[index] : nil
    }

    var hasNext: Bool { index + 1 < deck.count }
    var hasPrevious: Bool { index > 0 }

    /// "3 / 150" style position for the current deck.
    var progressText: String {
        deck.isEmpty ? "0 / 0" : "\(index + 1) / \(deck.count)"
    }

    /// Count of problems with a passing most-recent attempt (out of the full set).
    var solvedCount: Int {
        latestAttempts().values.filter { $0.finalScore >= Grade.passThreshold }.count
    }

    func goNext() {
        if hasNext { index += 1 }
    }

    func goPrevious() {
        if hasPrevious { index -= 1 }
    }

    // MARK: - Deck building

    func rebuild() {
        var problems: [Problem]
        switch query.filter {
        case .all:
            problems = allProblems
        case .failedOrDue:
            let failed = failedProblemIDs()
            problems = allProblems.filter { failed.contains($0.id) }
        }

        switch query.order {
        case .sequential:
            problems.sort { ($0.order ?? .max) < ($1.order ?? .max) }
        case .shuffled(let seed):
            var rng = SeededGenerator(seed: seed)
            problems.shuffle(using: &rng)
        }

        deck = problems
        index = 0
    }

    // MARK: - Attempt history

    /// Most recent attempt per problem id.
    func latestAttempts() -> [String: Attempt] {
        let all = (try? context.fetch(FetchDescriptor<Attempt>())) ?? []
        var latest: [String: Attempt] = [:]
        for attempt in all {
            if let existing = latest[attempt.problemID], existing.date >= attempt.date { continue }
            latest[attempt.problemID] = attempt
        }
        return latest
    }

    /// Problem ids whose most recent attempt is below the pass threshold.
    func failedProblemIDs() -> Set<String> {
        Set(
            latestAttempts().values
                .filter { $0.finalScore < Grade.passThreshold }
                .map(\.problemID)
        )
    }

    func latestAttempt(for problemID: String) -> Attempt? {
        latestAttempts()[problemID]
    }

    // MARK: - Grading + persistence

    /// Grade an answer against the current problem's reference idea.
    func grade(answer: String) async throws -> Grade {
        guard let problem = current else {
            throw GraderError.unavailable("No problem is selected.")
        }
        return try await grader.grade(coreIdea: problem.coreIdea, userAnswer: answer)
    }

    /// Persist the (possibly overridden) result for the current problem.
    @discardableResult
    func record(answer: String, llmScore: Int, finalScore: Int, rationale: String) -> Attempt? {
        guard let problem = current else { return nil }
        return record(problemID: problem.id, answer: answer, llmScore: llmScore, finalScore: finalScore, rationale: rationale)
    }

    /// Persist a result for a specific problem id.
    @discardableResult
    func record(problemID: String, answer: String, llmScore: Int, finalScore: Int, rationale: String) -> Attempt {
        let attempt = Attempt(
            problemID: problemID,
            userAnswer: answer,
            llmScore: llmScore,
            finalScore: finalScore,
            rationale: rationale
        )
        context.insert(attempt)
        try? context.save()
        return attempt
    }

    /// Build the testable per-card model wired to this store's grader + storage.
    func makeFlashcardModel(for problem: Problem) -> FlashcardModel {
        FlashcardModel(coreIdea: problem.coreIdea, grader: grader) { [weak self] answer, llmScore, finalScore, rationale in
            self?.record(
                problemID: problem.id,
                answer: answer,
                llmScore: llmScore,
                finalScore: finalScore,
                rationale: rationale
            )
        }
    }
}
