import Foundation
import Observation

/// The state machine + logic behind a single flashcard, extracted from the View
/// so the grade→override→save flow is unit-testable without any UI framework.
@MainActor
@Observable
final class FlashcardModel {
    enum Phase: Equatable {
        case answering
        case grading
        case graded(Grade)
    }

    var answer: String = ""
    private(set) var phase: Phase = .answering
    var finalScore: Int = 0
    private(set) var errorMessage: String?

    private let coreIdea: String
    private let grader: any Grading
    /// Persists the committed attempt (answer, llmScore, finalScore, rationale).
    private let save: (String, Int, Int, String) -> Void

    init(
        coreIdea: String,
        grader: any Grading,
        save: @escaping (String, Int, Int, String) -> Void
    ) {
        self.coreIdea = coreIdea
        self.grader = grader
        self.save = save
    }

    // MARK: - Pure rules (the testable seams)

    /// The answer box is only editable before grading begins.
    var isAnswerEditable: Bool { phase == .answering }

    /// Grading is allowed only when there's a non-blank answer.
    var canGrade: Bool {
        phase == .answering && !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var grade: Grade? {
        if case .graded(let g) = phase { return g }
        return nil
    }

    // MARK: - Transitions

    func grade() async {
        guard canGrade else { return }
        errorMessage = nil
        phase = .grading
        do {
            let result = try await grader.grade(coreIdea: coreIdea, userAnswer: answer)
            finalScore = result.score
            phase = .graded(result)
        } catch {
            errorMessage = error.localizedDescription
            phase = .answering
        }
    }

    /// Persist the (possibly overridden) result.
    func commit() {
        guard case .graded(let grade) = phase else { return }
        save(answer, grade.score, finalScore, grade.rationale)
    }
}
