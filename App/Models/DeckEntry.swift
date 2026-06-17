import Foundation
import SwiftData

/// Membership of a problem in the user's curated study deck. The deck is the set
/// of problems with a `DeckEntry`; the study view draws from these.
@Model
final class DeckEntry {
    @Attribute(.unique) var problemID: String
    var addedAt: Date

    init(problemID: String, addedAt: Date = .now) {
        self.problemID = problemID
        self.addedAt = addedAt
    }
}
