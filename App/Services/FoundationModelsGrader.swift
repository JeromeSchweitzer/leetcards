import Foundation

#if canImport(FoundationModels)
import FoundationModels

/// On-device grader backed by Apple's Foundation Models framework.
///
/// Grading material is small (only the reference `coreIdea` + the user's answer
/// — never the full solution code), and the rubric lives in the session's
/// `instructions` slot so the user's text can't redirect the grading task.
/// Guided generation constrains the output to a 0–100 score + rationale.
@available(macOS 26.0, iOS 26.0, *)
struct FoundationModelsGrader: Grading {
    @Generable
    struct GradeOutput {
        @Guide(description: "0 to 100: how fully the user's answer captures the essential approach of the reference idea", .range(0...100))
        var score: Int
        @Guide(description: "one or two sentences explaining the score")
        var rationale: String
    }

    static let instructions = """
        You grade a learner's short description of the *core idea* of a coding \
        problem against a reference idea. Judge only whether the learner \
        captured the essential algorithmic approach (the technique and why it \
        works) — ignore wording, spelling, language, and missing complexity \
        analysis. Award a high score when the central technique is present, a \
        middling score when the answer is partially right or vague, and a low \
        score when the approach is wrong or absent. Be encouraging but honest.
        """

    func grade(coreIdea: String, userAnswer: String) async throws -> Grade {
        switch SystemLanguageModel.default.availability {
        case .available:
            break
        case .unavailable(let reason):
            throw GraderError.unavailable(GraderAvailability.message(for: reason))
        @unknown default:
            throw GraderError.unavailable("The on-device model is unavailable.")
        }

        let session = LanguageModelSession(instructions: Self.instructions)
        let prompt = """
            Reference idea: \(coreIdea)

            Learner's answer: \(userAnswer)
            """
        let response = try await session.respond(to: prompt, generating: GradeOutput.self)
        let output = response.content
        return Grade(score: min(100, max(0, output.score)), rationale: output.rationale)
    }
}
#endif

enum GraderError: Error, LocalizedError {
    case unavailable(String)
    var errorDescription: String? {
        switch self {
        case .unavailable(let message): message
        }
    }
}

/// Resolves the best available grader and exposes a user-facing availability
/// message. Keeps all the `#if canImport` / `@available` fences in one place so
/// the rest of the app just depends on `any Grading`.
enum GraderFactory {
    /// Returns the on-device grader when Apple Intelligence is ready, otherwise
    /// the deterministic `MockGrader`.
    static func makeGrader() -> any Grading {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability {
                return FoundationModelsGrader()
            }
        }
        #endif
        return MockGrader()
    }

    /// A message to show when the real grader is unavailable, or `nil` when the
    /// on-device model is available and being used.
    static func availabilityMessage() -> String? {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return nil
            case .unavailable(let reason):
                return GraderAvailability.message(for: reason)
            @unknown default:
                return "On-device grading is unavailable; scoring manually."
            }
        }
        #endif
        return "On-device grading requires macOS/iOS 26+. Scoring manually."
    }
}

#if canImport(FoundationModels)
@available(macOS 26.0, iOS 26.0, *)
enum GraderAvailability {
    static func message(for reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .appleIntelligenceNotEnabled:
            "Apple Intelligence isn't enabled. Turn it on in Settings to grade automatically, or score manually."
        case .modelNotReady:
            "The on-device model is still downloading. You can score manually for now."
        case .deviceNotEligible:
            "This device can't run Apple Intelligence. Scoring manually."
        @unknown default:
            "On-device grading is unavailable. Scoring manually."
        }
    }
}
#endif
