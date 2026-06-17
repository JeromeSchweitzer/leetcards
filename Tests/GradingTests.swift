import Foundation
import Testing
@testable import LeetCards

@Suite("Grading")
struct GradingTests {

    @Test("isPass uses the 70 threshold (boundary)")
    func passBoundary() {
        #expect(!Grade(score: 69, rationale: "").isPass)
        #expect(Grade(score: 70, rationale: "").isPass)
        #expect(Grade(score: 100, rationale: "").isPass)
    }

    @Test("MockGrader is deterministic")
    func mockDeterministic() async throws {
        let grader = MockGrader()
        let a = try await grader.grade(coreIdea: "use a hash map", userAnswer: "a hash map")
        let b = try await grader.grade(coreIdea: "use a hash map", userAnswer: "a hash map")
        #expect(a == b)
    }

    @Test("MockGrader separates a strong answer from a weak one across the threshold")
    func mockStrongVsWeak() async throws {
        let grader = MockGrader()
        let strong = try await grader.grade(
            coreIdea: "use a hash map for constant time lookups",
            userAnswer: "use a hash map for constant time lookups"
        )
        let weak = try await grader.grade(
            coreIdea: "use a hash map for constant time lookups",
            userAnswer: "sort the array first"
        )
        #expect(strong.score > weak.score)
        #expect(strong.isPass)
        #expect(!weak.isPass)
    }

    @Test("An empty answer scores 0")
    func emptyAnswerScoresZero() async throws {
        let grade = try await MockGrader().grade(coreIdea: "use a hash map", userAnswer: "")
        #expect(grade.score == 0)
    }

    @Test("GraderFactory returns a grader and an availability signal without crashing")
    func factoryResolves() {
        // NOTE: we deliberately do NOT call .grade() on the factory's grader —
        // on an Apple-Intelligence-capable machine it would make a real on-device
        // model call (slow / blocking in the test harness). Live grading is only
        // exercised through MockGrader above; here we just confirm the factory
        // resolves a grader and the availability message path doesn't crash.
        _ = GraderFactory.makeGrader()
        _ = GraderFactory.availabilityMessage()
    }
}
