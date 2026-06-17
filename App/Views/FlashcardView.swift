import SwiftUI

/// A single flashcard: shows the problem, takes the user's core-idea answer,
/// grades it, then shows the result with an editable score override.
///
/// The grade flow lives in `FlashcardModel` (testable); this view is a thin
/// shell over it. The parent keys this view by problem id so moving to another
/// card starts fresh.
struct FlashcardView: View {
    let problem: Problem
    let store: DeckStore
    /// The card's model is owned by the store (so the deck can observe its
    /// review state); this view just drives it.
    @Bindable var model: FlashcardModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                description

                VStack(alignment: .leading, spacing: 6) {
                    Text("Your core idea").font(.headline)
                    TextEditor(text: $model.answer)
                        .font(.body)
                        .frame(minHeight: 120)
                        .padding(6)
                        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                        .disabled(!model.isAnswerEditable)
                }

                if let errorMessage = model.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }

                actionArea
            }
            .padding()
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let number = problem.number {
                    Text("#\(number)").foregroundStyle(.secondary)
                }
                Text(problem.title).font(.title2.weight(.semibold))
                Spacer()
                if let difficulty = problem.difficulty {
                    DifficultyBadge(difficulty: difficulty)
                }
            }
            if !problem.tags.isEmpty {
                Text(problem.tags.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var description: some View {
        MarkdownView(text: problem.description)
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var actionArea: some View {
        switch model.phase {
        case .answering:
            Button {
                Task { await model.grade() }
            } label: {
                Label("Grade", systemImage: "checkmark.seal")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.canGrade)

        case .grading:
            HStack {
                ProgressView()
                Text("Grading…").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

        case .graded(let grade):
            VStack(alignment: .leading, spacing: 16) {
                GradeResultView(problem: problem, grade: grade, finalScore: $model.finalScore)
                Button {
                    model.commit()
                    if store.hasNext {
                        store.goNext()
                    } else {
                        store.finishDeck()
                    }
                } label: {
                    Label(store.hasNext ? "Save & Next" : "Save & Finish", systemImage: store.hasNext ? "arrow.right" : "flag.checkered")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

struct DifficultyBadge: View {
    let difficulty: Difficulty
    @Environment(\.palette) private var palette

    var body: some View {
        let color = palette.difficultyColor(difficulty)
        Text(difficulty.rawValue)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }
}
