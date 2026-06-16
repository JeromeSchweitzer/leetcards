import Foundation
import SwiftData
import Testing
@testable import LeetCards

@MainActor
@Suite("DeckStore")
struct DeckStoreTests {

    private func sampleProblems(_ n: Int) -> [Problem] {
        (0..<n).map { i in
            Problem(
                id: "p\(i)",
                title: "Problem \(i)",
                order: i,
                coreIdea: "use a hash map for constant time lookups",
                solutions: [Solution(title: "s", language: "python", code: "pass")]
            )
        }
    }

    private func makeStore(
        problems: [Problem],
        query: DeckQuery = DeckQuery(order: .sequential)
    ) throws -> DeckStore {
        let container = try PersistenceStore.makeInMemoryContainer()
        // A dedicated context (not `mainContext`): SwiftData's main context
        // expects the real main thread/run loop, which the swift-testing async
        // harness doesn't provide. The app itself uses `mainContext` on the
        // real UI thread, which is correct.
        return DeckStore(
            problems: problems,
            context: ModelContext(container),
            grader: MockGrader(),
            query: query
        )
    }

    @Test("Seeded shuffle is deterministic and a different seed reorders")
    func seededShuffleDeterministic() throws {
        let problems = sampleProblems(30)
        let a = try makeStore(problems: problems, query: DeckQuery(order: .shuffled(seed: 42)))
        let b = try makeStore(problems: problems, query: DeckQuery(order: .shuffled(seed: 42)))
        let c = try makeStore(problems: problems, query: DeckQuery(order: .shuffled(seed: 7)))

        #expect(a.deck.map(\.id) == b.deck.map(\.id))          // same seed -> same order
        #expect(a.deck.map(\.id) != c.deck.map(\.id))          // different seed -> different order
        #expect(Set(a.deck.map(\.id)) == Set(problems.map(\.id))) // shuffle keeps all problems
    }

    @Test("Sequential order respects each problem's order field")
    func sequentialOrder() throws {
        let store = try makeStore(problems: sampleProblems(5), query: DeckQuery(order: .sequential))
        #expect(store.deck.map(\.id) == ["p0", "p1", "p2", "p3", "p4"])
    }

    @Test("Review-failed queue contains only problems whose latest attempt failed")
    func failedQueueSelection() throws {
        let store = try makeStore(problems: sampleProblems(4), query: DeckQuery(order: .sequential))

        // p1 fails; p2 passes; p3 first fails then passes (latest wins).
        store.index = 1
        store.record(answer: "x", llmScore: 20, finalScore: 20, rationale: "")
        store.index = 2
        store.record(answer: "x", llmScore: 90, finalScore: 90, rationale: "")
        store.index = 3
        store.record(answer: "x", llmScore: 10, finalScore: 10, rationale: "")
        store.record(answer: "x", llmScore: 95, finalScore: 95, rationale: "")

        store.query = DeckQuery(order: .sequential, filter: .failedOrDue)
        #expect(store.deck.map(\.id) == ["p1"])
        #expect(store.solvedCount == 2)   // p2 and p3 pass
    }

    @Test("Grade-and-save flow records an attempt via MockGrader")
    func gradeAndSaveFlow() async throws {
        let store = try makeStore(problems: sampleProblems(3), query: DeckQuery(order: .sequential))
        store.index = 0

        // Strong answer (overlaps the reference idea) should pass; weak shouldn't.
        let strong = try await store.grade(answer: "use a hash map for constant time lookups")
        #expect(strong.isPass)
        let weak = try await store.grade(answer: "sort everything")
        #expect(!weak.isPass)

        store.record(answer: "use a hash map", llmScore: strong.score, finalScore: strong.score, rationale: strong.rationale)
        let saved = try #require(store.latestAttempt(for: "p0"))
        #expect(saved.finalScore == strong.score)
        #expect(saved.problemID == "p0")
    }

    @Test("Score override is what persists, not the model score")
    func overridePersists() throws {
        let store = try makeStore(problems: sampleProblems(2), query: DeckQuery(order: .sequential))
        store.index = 0
        store.record(answer: "x", llmScore: 30, finalScore: 80, rationale: "overridden")
        let saved = try #require(store.latestAttempt(for: "p0"))
        #expect(saved.llmScore == 30)
        #expect(saved.finalScore == 80)
        #expect(store.solvedCount == 1)   // 80 >= threshold
    }
}
