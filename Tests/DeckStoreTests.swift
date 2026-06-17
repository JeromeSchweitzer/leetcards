import Foundation
import Observation
import SwiftData
import Testing
@testable import LeetCards

/// Sendable box so the Observation onChange closure can flip a flag the test reads.
private final class Flag: @unchecked Sendable {
    var value = false
}

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
        let store = DeckStore(
            problems: problems,
            context: ModelContext(container),
            grader: MockGrader(),
            query: query
        )
        // The deck is curated; seed all sample problems so the deck is non-empty
        // (mirrors the app's first-run seeding).
        store.seedDeckIfNeeded(seeded: false) {}
        return store
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

    @Test("Navigation clamps at both ends")
    func navigationBounds() throws {
        let store = try makeStore(problems: sampleProblems(3), query: DeckQuery(order: .sequential))
        #expect(!store.hasPrevious)
        #expect(store.hasNext)
        store.goPrevious()                 // no-op at the start
        #expect(store.index == 0)
        store.goNext(); store.goNext()
        #expect(store.index == 2)
        #expect(store.hasPrevious)
        #expect(!store.hasNext)
        store.goNext()                     // no-op at the end
        #expect(store.index == 2)
    }

    @Test("Changing the query rebuilds the deck and resets the index to 0")
    func queryChangeResetsIndex() throws {
        let store = try makeStore(problems: sampleProblems(5), query: DeckQuery(order: .sequential))
        store.goNext(); store.goNext()
        #expect(store.index == 2)
        store.query = DeckQuery(order: .shuffled(seed: 1))
        #expect(store.index == 0)
        #expect(Set(store.deck.map(\.id)).count == 5)   // still the full set
    }

    @Test("Empty failed/due queue leaves no current card")
    func emptyFailedQueue() throws {
        let store = try makeStore(problems: sampleProblems(3), query: DeckQuery(order: .sequential))
        store.query = DeckQuery(order: .sequential, filter: .failedOrDue)
        #expect(store.deck.isEmpty)
        #expect(store.current == nil)      // drives the empty-state view
    }

    @Test("Deck membership: add / remove / clear / isInDeck and rebuild reflects it")
    func deckMembership() throws {
        let store = try makeStore(problems: sampleProblems(5))   // seeded: all 5 in deck
        #expect(store.isInDeck("p0"))
        store.removeFromDeck("p0")
        #expect(!store.isInDeck("p0"))
        #expect(store.deck.map(\.id) == ["p1", "p2", "p3", "p4"])
        store.addToDeck("p0")
        #expect(store.isInDeck("p0"))
        #expect(store.deck.count == 5)
        store.clearDeck()
        #expect(store.deck.isEmpty)
        #expect(store.current == nil)        // drives the empty-state view
    }

    @Test("Toggling deck membership repeatedly stays consistent")
    func repeatedToggle() throws {
        let store = try makeStore(problems: sampleProblems(3))  // all 3 seeded into the deck
        for _ in 0..<5 {
            store.toggleDeck("p1")
            #expect(!store.isInDeck("p1"))   // removed
            store.toggleDeck("p1")
            #expect(store.isInDeck("p1"))    // re-added
        }
        #expect(store.deck.count == 3)
    }

    @Test("Toggling deck membership fires an observation (so the UI re-renders)")
    func togglingNotifiesObservers() throws {
        // This is the real regression test for the selection bug: reading
        // membership must register an Observation dependency that fires on a
        // toggle. The old fetch-based `selectedProblemIDs()` accessed no
        // observable state, so observers never fired and the UI lagged.
        let store = try makeStore(problems: sampleProblems(3))   // all seeded
        let flag = Flag()
        withObservationTracking {
            _ = store.selectedProblemIDs()
        } onChange: {
            flag.value = true
        }
        store.toggleDeck("p1")
        #expect(flag.value, "toggling membership should notify observers of selectedProblemIDs()")
    }

    @Test("Membership updates synchronously and mirrors the persisted store")
    func membershipMirrorsPersistence() throws {
        // Guards the selection bug: the observable in-memory `deckIDs` must update
        // immediately and stay consistent with what's persisted, so the UI reflects
        // toggles on the first click.
        let container = try PersistenceStore.makeInMemoryContainer()
        let store = DeckStore(problems: sampleProblems(4), context: ModelContext(container),
                              grader: MockGrader(), query: DeckQuery(order: .sequential))
        store.seedDeckIfNeeded(seeded: false) {}

        store.toggleDeck("p1")                       // remove
        #expect(!store.isInDeck("p1"))               // reflected synchronously
        store.toggleDeck("p1")                       // add back
        #expect(store.isInDeck("p1"))
        store.removeFromDeck("p2")
        let expected: Set = ["p0", "p1", "p3"]
        #expect(store.selectedProblemIDs() == expected)

        // A fresh store on the same container must agree (in-memory mirror is correct).
        let relaunched = DeckStore(problems: sampleProblems(4), context: ModelContext(container),
                                   grader: MockGrader())
        #expect(relaunched.selectedProblemIDs() == expected)
    }

    @Test("Finishing the deck sets isFinished; summary reflects results; nav resets it")
    func finishSummary() throws {
        let store = try makeStore(problems: sampleProblems(3))  // p0, p1, p2 sequential
        #expect(!store.isFinished)
        store.record(problemID: "p0", answer: "x", llmScore: 80, finalScore: 80, rationale: "")
        store.record(problemID: "p1", answer: "x", llmScore: 50, finalScore: 50, rationale: "")
        // p2 left unattempted
        store.finishDeck()
        #expect(store.isFinished)

        let summary = store.deckSummary()
        #expect(summary.total == 3)
        #expect(summary.attempted == 2)
        #expect(summary.passed == 1)         // 80 passes, 50 doesn't
        #expect(summary.averageScore == 65)  // (80 + 50) / 2

        store.query = DeckQuery(order: .sequential)  // rebuild clears the finished state
        #expect(!store.isFinished)
    }

    @Test("select jumps to a problem, adding it to the deck if missing")
    func selectJumps() throws {
        let store = try makeStore(problems: sampleProblems(5))
        store.clearDeck()
        store.select(problemID: "p3")
        #expect(store.isInDeck("p3"))
        #expect(store.current?.id == "p3")
    }

    @Test("isReviewing reflects the current card's graded state")
    func isReviewingReflectsCard() async throws {
        let store = try makeStore(problems: sampleProblems(3))
        #expect(!store.isReviewing)
        store.currentCard?.answer = "use a hash map for constant time lookups"
        await store.currentCard?.grade()
        #expect(store.isReviewing)
        store.goNext()
        #expect(!store.isReviewing)          // the next card starts fresh
    }

    @Test("stats reports attempt count and the most recent final score")
    func statsReporting() throws {
        let store = try makeStore(problems: sampleProblems(2))
        #expect(store.stats(for: "p0") == ProblemStats(attemptCount: 0, lastScore: nil))
        store.record(problemID: "p0", answer: "x", llmScore: 40, finalScore: 40, rationale: "")
        store.record(problemID: "p0", answer: "y", llmScore: 90, finalScore: 85, rationale: "")
        let stats = store.stats(for: "p0")
        #expect(stats.attemptCount == 2)
        #expect(stats.lastScore == 85)
        #expect(store.allStats()["p0"] == stats)
    }

    @Test("Attempt history persists across a store re-init on the same container")
    func historyPersistsAcrossReinit() throws {
        let container = try PersistenceStore.makeInMemoryContainer()
        let problems = sampleProblems(3)

        let first = DeckStore(problems: problems, context: ModelContext(container),
                              grader: MockGrader(), query: DeckQuery(order: .sequential))
        first.record(problemID: "p1", answer: "x", llmScore: 88, finalScore: 88, rationale: "")

        // A fresh store over the same container should see the saved attempt.
        let second = DeckStore(problems: problems, context: ModelContext(container),
                               grader: MockGrader(), query: DeckQuery(order: .sequential))
        let saved = try #require(second.latestAttempt(for: "p1"))
        #expect(saved.finalScore == 88)
        #expect(second.solvedCount == 1)
    }
}
