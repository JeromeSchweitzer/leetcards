import Foundation
import Observation
import SwiftData

/// Per-problem study stats shown in the problem browser.
struct ProblemStats: Equatable, Sendable {
    var attemptCount: Int
    /// The most recent attempt's final score, or nil if never attempted.
    var lastScore: Int?
}

/// Results over a deck, shown on the finish screen.
struct DeckSummary: Equatable, Sendable {
    var total: Int
    var attempted: Int
    var passed: Int
    var averageScore: Int?
}

/// The deck's state: which problems are in play (per `DeckQuery`), where we are
/// in them, and the bridge to grading + persistence.
///
/// Built around a `DeckQuery` so order/filter changes (shuffle, sequential,
/// review-failed) just call `rebuild()` rather than introducing new code paths.
@MainActor
@Observable
final class DeckStore {
    /// The full catalog of problems (the curated deck is a subset of these).
    let allProblems: [Problem]
    private let problemsByID: [String: Problem]
    private let context: ModelContext
    let grader: any Grading

    /// The problems currently in the deck, after curated selection + filter +
    /// order are applied.
    private(set) var deck: [Problem] = []
    /// Index of the current card within `deck`.
    var index: Int = 0
    /// The model backing the current card. Owned here so the deck view can react
    /// to its review state (e.g. disable navigation while reviewing a grade).
    private(set) var currentCard: FlashcardModel?
    /// True once the user saves the last card — drives the summary screen.
    private(set) var isFinished = false

    var query: DeckQuery {
        didSet { rebuild() }
    }

    /// In-memory mirror of the persisted curated-deck membership. This is the
    /// observable source of truth the views read, so toggling updates the UI
    /// immediately (a raw SwiftData fetch isn't observed and lagged the UI).
    private(set) var deckIDs: Set<String> = []

    init(
        problems: [Problem],
        context: ModelContext,
        grader: any Grading,
        query: DeckQuery = DeckQuery()
    ) {
        self.allProblems = problems
        self.problemsByID = Dictionary(problems.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        self.context = context
        self.grader = grader
        self.query = query
        loadDeckIDs()
        rebuild()
    }

    private func loadDeckIDs() {
        let entries = (try? context.fetch(FetchDescriptor<DeckEntry>())) ?? []
        deckIDs = Set(entries.map(\.problemID))
    }

    // MARK: - Navigation

    var current: Problem? {
        deck.indices.contains(index) ? deck[index] : nil
    }

    var hasNext: Bool { index + 1 < deck.count }
    var hasPrevious: Bool { index > 0 }

    /// True while the current card is showing a grade (Save advances instead).
    var isReviewing: Bool { currentCard?.isReviewing ?? false }

    /// "3 / 150" style position for the current deck.
    var progressText: String {
        deck.isEmpty ? "0 / 0" : "\(index + 1) / \(deck.count)"
    }

    /// Count of problems with a passing most-recent attempt (out of the full set).
    var solvedCount: Int {
        latestAttempts().values.filter { $0.finalScore >= Grade.passThreshold }.count
    }

    func goNext() {
        if hasNext { index += 1; isFinished = false; refreshCurrentCard() }
    }

    func goPrevious() {
        if hasPrevious { index -= 1; isFinished = false; refreshCurrentCard() }
    }

    /// Mark the deck complete (called after saving the last card).
    func finishDeck() {
        isFinished = true
    }

    /// Jump to a specific problem to study it, adding it to the deck if needed.
    func select(problemID id: String) {
        if !deckIDs.contains(id) {
            context.insert(DeckEntry(problemID: id))
            try? context.save()
            deckIDs.insert(id)
        }
        rebuild()
        if let idx = deck.firstIndex(where: { $0.id == id }) {
            index = idx
            refreshCurrentCard()
        }
    }

    private func refreshCurrentCard() {
        currentCard = current.map { makeFlashcardModel(for: $0) }
    }

    // MARK: - Deck building

    func rebuild() {
        var problems = allProblems.filter { deckIDs.contains($0.id) }

        switch query.filter {
        case .all:
            break
        case .failedOrDue:
            let failed = failedProblemIDs()
            problems = problems.filter { failed.contains($0.id) }
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
        isFinished = false
        refreshCurrentCard()
    }

    /// Summary of the user's results over the current deck (for the finish screen).
    func deckSummary() -> DeckSummary {
        let latest = latestAttempts()
        let scores = deck.compactMap { latest[$0.id]?.finalScore }
        let passed = scores.filter { $0 >= Grade.passThreshold }.count
        let average = scores.isEmpty ? nil : Int((Double(scores.reduce(0, +)) / Double(scores.count)).rounded())
        return DeckSummary(total: deck.count, attempted: scores.count, passed: passed, averageScore: average)
    }

    // MARK: - Curated deck membership

    func selectedProblemIDs() -> Set<String> { deckIDs }

    func isInDeck(_ id: String) -> Bool { deckIDs.contains(id) }

    func addToDeck(_ id: String) {
        guard !deckIDs.contains(id) else { return }
        context.insert(DeckEntry(problemID: id))
        try? context.save()
        deckIDs.insert(id)
        rebuild()
    }

    func removeFromDeck(_ id: String) {
        let descriptor = FetchDescriptor<DeckEntry>(predicate: #Predicate { $0.problemID == id })
        for entry in (try? context.fetch(descriptor)) ?? [] { context.delete(entry) }
        try? context.save()
        deckIDs.remove(id)
        rebuild()
    }

    func toggleDeck(_ id: String) {
        deckIDs.contains(id) ? removeFromDeck(id) : addToDeck(id)
    }

    func clearDeck() {
        for entry in (try? context.fetch(FetchDescriptor<DeckEntry>())) ?? [] { context.delete(entry) }
        try? context.save()
        deckIDs.removeAll()
        rebuild()
    }

    /// Seed the deck with every problem the first time the app runs.
    func seedDeckIfNeeded(seeded: Bool, markSeeded: () -> Void) {
        guard !seeded else { return }
        for problem in allProblems where !deckIDs.contains(problem.id) {
            context.insert(DeckEntry(problemID: problem.id))
        }
        try? context.save()
        deckIDs = Set(allProblems.map(\.id))
        markSeeded()
        rebuild()
    }

    // MARK: - Per-problem stats

    func stats(for id: String) -> ProblemStats {
        let descriptor = FetchDescriptor<Attempt>(
            predicate: #Predicate { $0.problemID == id },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let attempts = (try? context.fetch(descriptor)) ?? []
        return ProblemStats(attemptCount: attempts.count, lastScore: attempts.first?.finalScore)
    }

    /// All per-problem stats in one fetch (for the problem browser).
    func allStats() -> [String: ProblemStats] {
        let attempts = (try? context.fetch(
            FetchDescriptor<Attempt>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        )) ?? []
        var grouped: [String: [Attempt]] = [:]
        for attempt in attempts { grouped[attempt.problemID, default: []].append(attempt) }
        return grouped.mapValues { list in
            ProblemStats(attemptCount: list.count, lastScore: list.first?.finalScore)
        }
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

    // MARK: - Flashcard model

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
