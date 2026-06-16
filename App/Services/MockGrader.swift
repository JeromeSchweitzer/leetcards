import Foundation

/// A deterministic, offline grader used on the Simulator, in unit tests, and
/// whenever Apple Intelligence is unavailable.
///
/// It is intentionally simple — a token-overlap heuristic between the reference
/// core idea and the user's answer — but it is *deterministic*, which is what
/// lets `DeckStoreTests` assert a stable grade→save flow without a real model.
struct MockGrader: Grading {
    func grade(coreIdea: String, userAnswer: String) async throws -> Grade {
        let reference = Self.tokens(coreIdea)
        let answer = Self.tokens(userAnswer)

        guard !answer.isEmpty else {
            return Grade(score: 0, rationale: "No answer was provided.")
        }
        guard !reference.isEmpty else {
            return Grade(score: 0, rationale: "No reference idea is available to grade against.")
        }

        let overlap = reference.intersection(answer).count
        let score = min(100, Int((Double(overlap) / Double(reference.count) * 100).rounded()))
        let rationale: String
        switch score {
        case Grade.passThreshold...:
            rationale = "Your answer covers the key concepts of the reference idea."
        case 40..<Grade.passThreshold:
            rationale = "Partial match — some key concepts are present but the core technique isn't fully captured."
        default:
            rationale = "Your answer is missing most of the reference idea's key concepts."
        }
        return Grade(score: score, rationale: rationale)
    }

    /// Lowercased significant word tokens (stop words and short tokens removed).
    static func tokens(_ text: String) -> Set<String> {
        let stop: Set<String> = [
            "the", "a", "an", "and", "or", "of", "to", "in", "is", "it", "for",
            "with", "on", "at", "by", "as", "be", "this", "that", "each", "from",
            "into", "its", "so", "if", "we", "you", "your", "are", "was",
        ]
        let separators = CharacterSet.alphanumerics.inverted
        return Set(
            text.lowercased()
                .components(separatedBy: separators)
                .filter { $0.count > 2 && !stop.contains($0) }
        )
    }
}
