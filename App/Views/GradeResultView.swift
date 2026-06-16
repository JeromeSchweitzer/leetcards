import SwiftUI

/// Shows the grade for an answer: the LLM score + rationale, an editable score
/// override, the reference core idea, and the tabbed solution code.
struct GradeResultView: View {
    let problem: Problem
    let grade: Grade
    /// The user's possibly-overridden final score (bound by the parent).
    @Binding var finalScore: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            scoreHeader

            VStack(alignment: .leading, spacing: 6) {
                Text("Why").font(.headline)
                Text(grade.rationale)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Label("Reference idea", systemImage: "lightbulb")
                    .font(.headline)
                Text(problem.coreIdea)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Reference solutions").font(.headline)
                SolutionsTabView(solutions: problem.solutions)
            }
        }
    }

    private var scoreHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(finalScore)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(verdictColor)
                Text("/ 100").foregroundStyle(.secondary)
                Spacer()
                Text(finalScore >= Grade.passThreshold ? "Pass" : "Review")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(verdictColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(verdictColor)
            }

            HStack(spacing: 8) {
                Text("Override")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Slider(
                    value: Binding(
                        get: { Double(finalScore) },
                        set: { finalScore = Int($0.rounded()) }
                    ),
                    in: 0...100,
                    step: 1
                )
                Stepper("", value: $finalScore, in: 0...100)
                    .labelsHidden()
            }
            if finalScore != grade.score {
                Text("Adjusted from the model's \(grade.score).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var verdictColor: Color {
        finalScore >= Grade.passThreshold ? .green : .orange
    }
}
