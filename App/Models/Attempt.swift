import Foundation
import SwiftData

/// A persisted grading attempt for one problem.
///
/// `problemID` is the LeetCode slug, deliberately decoupled from the dataset's
/// order/numbering so re-scraping or reordering the dataset preserves history.
/// `llmScore` is the model's 0–100 score; `finalScore` is what the user kept
/// after any override and is what the review queue / progress read from.
@Model
final class Attempt {
    var problemID: String
    var userAnswer: String
    var llmScore: Int
    var finalScore: Int
    var rationale: String
    var date: Date

    init(
        problemID: String,
        userAnswer: String,
        llmScore: Int,
        finalScore: Int,
        rationale: String,
        date: Date = .now
    ) {
        self.problemID = problemID
        self.userAnswer = userAnswer
        self.llmScore = llmScore
        self.finalScore = finalScore
        self.rationale = rationale
        self.date = date
    }
}
