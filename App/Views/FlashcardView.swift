import SwiftUI

/// A single flashcard: shows the problem, takes the user's core-idea answer,
/// grades it, then shows the result with an editable score override.
///
/// State is intentionally per-problem; the parent keys this view by problem id
/// so moving to another card starts fresh.
struct FlashcardView: View {
    let problem: Problem
    let store: DeckStore

    private enum Phase: Equatable {
        case answering
        case grading
        case graded(Grade)
    }

    @State private var answer: String = ""
    @State private var phase: Phase = .answering
    @State private var finalScore: Int = 0
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                description

                VStack(alignment: .leading, spacing: 6) {
                    Text("Your core idea").font(.headline)
                    TextEditor(text: $answer)
                        .font(.body)
                        .frame(minHeight: 120)
                        .padding(6)
                        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                        .disabled(phase != .answering)
                }

                if let errorMessage {
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
        Text(problem.description)
            .font(.callout)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var actionArea: some View {
        switch phase {
        case .answering:
            Button {
                gradeAnswer()
            } label: {
                Label("Grade", systemImage: "checkmark.seal")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        case .grading:
            HStack {
                ProgressView()
                Text("Grading…").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

        case .graded(let grade):
            VStack(alignment: .leading, spacing: 16) {
                GradeResultView(problem: problem, grade: grade, finalScore: $finalScore)
                Button {
                    saveAndContinue(grade: grade)
                } label: {
                    Label(store.hasNext ? "Save & Next" : "Save & Finish", systemImage: "arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Actions

    private func gradeAnswer() {
        errorMessage = nil
        phase = .grading
        Task {
            do {
                let grade = try await store.grade(answer: answer)
                finalScore = grade.score
                phase = .graded(grade)
            } catch {
                errorMessage = error.localizedDescription
                phase = .answering
            }
        }
    }

    private func saveAndContinue(grade: Grade) {
        store.record(
            answer: answer,
            llmScore: grade.score,
            finalScore: finalScore,
            rationale: grade.rationale
        )
        store.goNext()
    }
}

struct DifficultyBadge: View {
    let difficulty: Difficulty

    var body: some View {
        Text(difficulty.rawValue)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private var color: Color {
        switch difficulty {
        case .easy: .green
        case .medium: .orange
        case .hard: .red
        }
    }
}
