import Foundation
import SwiftData
import Testing
@testable import LeetCards

/// Integration tests that exercise whole user flows end-to-end through the
/// store + flashcard model + grader (the closest to UI-level coverage we can get
/// without a UI test harness). Each test chains the steps a real user takes.
@MainActor
@Suite("User flows")
struct UserFlowTests {

    private func problems(_ n: Int) -> [Problem] {
        (0..<n).map { i in
            Problem(id: "p\(i)", title: "Problem \(i)", number: i + 1, order: i,
                    difficulty: [.easy, .medium, .hard][i % 3],
                    coreIdea: "use a hash map for constant time lookups",
                    tags: [["array"], ["string"], ["tree"]][i % 3],
                    solutions: [Solution(title: "s", language: "python", code: "pass")])
        }
    }

    /// Build a store with its own in-memory container, optionally seeding the deck.
    private func freshStore(_ n: Int, seed: Bool = true,
                            order: DeckQuery.Order = .sequential,
                            container: ModelContainer? = nil) throws -> DeckStore {
        let c = try container ?? PersistenceStore.makeInMemoryContainer()
        let store = DeckStore(problems: problems(n), context: ModelContext(c),
                              grader: MockGrader(), query: DeckQuery(order: order))
        if seed { store.seedDeckIfNeeded(seeded: false) {} }
        return store
    }

    @Test("First launch: deck is seeded with all problems and starts at the first")
    func firstLaunchSeed() throws {
        let store = try freshStore(10)
        #expect(store.deck.count == 10)
        #expect(store.current?.id == "p0")
        #expect(store.selectedProblemIDs().count == 10)
    }

    @Test("Study flow: grade → override → save advances and persists the override")
    func studyGradeOverrideSave() async throws {
        let store = try freshStore(3)
        let card = try #require(store.currentCard)            // p0
        card.answer = "use a hash map for constant time lookups"
        await card.grade()
        #expect(store.isReviewing)                            // nav disabled here
        card.finalScore = 75                                   // user overrides
        card.commit()
        store.goNext()
        #expect(store.current?.id == "p1")
        #expect(!store.isReviewing)
        let saved = try #require(store.latestAttempt(for: "p0"))
        #expect(saved.finalScore == 75)
    }

    @Test("Finish flow: grading through the last card reaches the summary")
    func finishFlow() async throws {
        let store = try freshStore(2)
        for _ in 0..<2 {
            let card = try #require(store.currentCard)
            card.answer = "use a hash map for constant time lookups"
            await card.grade()
            card.commit()
            if store.hasNext { store.goNext() } else { store.finishDeck() }
        }
        #expect(store.isFinished)
        let summary = store.deckSummary()
        #expect(summary.total == 2)
        #expect(summary.attempted == 2)
    }

    @Test("Curate flow: clear the deck, add two problems, study only those")
    func curateFlow() throws {
        let store = try freshStore(10)
        store.clearDeck()
        #expect(store.deck.isEmpty)
        store.addToDeck("p3")
        store.addToDeck("p7")
        #expect(Set(store.deck.map(\.id)) == ["p3", "p7"])
        #expect(store.current != nil)
    }

    @Test("Review-failed flow: a failed card appears in the queue, then leaves after a passing re-grade")
    func reviewFailedFlow() async throws {
        let store = try freshStore(3)
        // Fail p0.
        let card = try #require(store.currentCard)
        card.answer = "totally unrelated"
        await card.grade()
        card.finalScore = 10
        card.commit()

        store.query = DeckQuery(order: .sequential, filter: .failedOrDue)
        #expect(store.deck.map(\.id) == ["p0"])

        // Re-grade p0 with a passing override.
        let card2 = try #require(store.currentCard)
        card2.answer = "use a hash map for constant time lookups"
        await card2.grade()
        card2.finalScore = 90
        card2.commit()

        store.rebuild()
        #expect(store.deck.isEmpty)                            // no longer failing
    }

    @Test("Select-from-list flow: tapping a problem studies it")
    func selectFromListFlow() throws {
        let store = try freshStore(10, order: .shuffled(seed: 1))
        store.select(problemID: "p5")
        #expect(store.current?.id == "p5")
        #expect(store.isInDeck("p5"))
    }

    @Test("Persistence flow: deck membership + attempts survive a relaunch")
    func persistenceFlow() async throws {
        let container = try PersistenceStore.makeInMemoryContainer()
        let store = try freshStore(5, container: container)
        store.clearDeck()
        store.addToDeck("p2")
        let card = try #require(store.currentCard)            // p2
        card.answer = "use a hash map for constant time lookups"
        await card.grade()
        card.commit()

        // Relaunch against the same container.
        let relaunched = try freshStore(5, seed: false, container: container)
        #expect(relaunched.deck.map(\.id) == ["p2"])
        #expect(relaunched.latestAttempt(for: "p2") != nil)
    }
}
