import Foundation
import Testing
@testable import LeetCards

@MainActor
@Suite("FlashcardModel")
struct FlashcardModelTests {

    private func makeModel(
        coreIdea: String = "use a hash map for constant time lookups",
        grader: any Grading = MockGrader(),
        onSave: @escaping (String, Int, Int, String) -> Void = { _, _, _, _ in }
    ) -> FlashcardModel {
        FlashcardModel(coreIdea: coreIdea, grader: grader, save: onSave)
    }

    @Test("canGrade requires a non-blank answer")
    func canGradeRule() {
        let model = makeModel()
        #expect(!model.canGrade)            // empty
        model.answer = "   \n  "
        #expect(!model.canGrade)            // whitespace only
        model.answer = "hash map"
        #expect(model.canGrade)
    }

    @Test("The answer is editable only while answering")
    func editabilityRule() async {
        let model = makeModel()
        #expect(model.isAnswerEditable)     // starts answering
        model.answer = "hash map"
        await model.grade()
        #expect(model.phase == .graded(model.grade!))
        #expect(!model.isAnswerEditable)    // not editable once graded
    }

    @Test("grade() transitions to graded and sets finalScore from the grade")
    func gradeTransition() async {
        let model = makeModel()
        model.answer = "use a hash map for constant time lookups"
        await model.grade()
        let grade = try? #require(model.grade)
        #expect(grade != nil)
        #expect(model.finalScore == model.grade?.score)
        #expect(model.grade!.isPass)        // strong answer passes via MockGrader
    }

    @Test("A grader error returns to answering with an error message")
    func gradeError() async {
        struct FailingGrader: Grading {
            func grade(coreIdea: String, userAnswer: String) async throws -> Grade {
                throw GraderError.unavailable("boom")
            }
        }
        let model = makeModel(grader: FailingGrader())
        model.answer = "anything"
        await model.grade()
        #expect(model.phase == .answering)
        #expect(model.errorMessage != nil)
    }

    @Test("commit() persists the overridden final score, not the model score")
    func commitPersistsOverride() async {
        var saved: (answer: String, llm: Int, final: Int, rationale: String)?
        let model = makeModel { answer, llm, final, rationale in
            saved = (answer, llm, final, rationale)
        }
        model.answer = "use a hash map for constant time lookups"
        await model.grade()
        let llmScore = model.grade!.score
        model.finalScore = 42            // user override
        model.commit()
        #expect(saved?.llm == llmScore)
        #expect(saved?.final == 42)
    }

    @Test("commit() before grading does nothing")
    func commitNoopBeforeGrading() {
        var didSave = false
        let model = makeModel { _, _, _, _ in didSave = true }
        model.commit()
        #expect(!didSave)
    }
}
