import Foundation

/// The result of grading a user's answer against a reference core idea.
struct Grade: Sendable, Equatable {
    /// 0–100: how fully the answer captures the essential approach.
    let score: Int
    /// One or two sentences explaining the score.
    let rationale: String
}

/// The grading abstraction the UI depends on.
///
/// Concrete backends — `FoundationModelsGrader` (on-device) and `MockGrader`
/// (deterministic, for the Simulator/dev/tests) — are interchangeable, and a
/// future cloud or alternate-model backend can drop in without touching views.
protocol Grading: Sendable {
    func grade(coreIdea: String, userAnswer: String) async throws -> Grade
}

extension Grade {
    /// The default pass threshold mapping a score to pass/fail for the review
    /// queue. Kept here so the store and views share one source of truth.
    static let passThreshold = 70

    var isPass: Bool { score >= Grade.passThreshold }
}
