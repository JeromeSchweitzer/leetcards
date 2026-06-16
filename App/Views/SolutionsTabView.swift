import SwiftUI

/// Lets the user tab between the full code of the scraped top solutions while
/// reviewing their answer. Monospaced, horizontally + vertically scrollable.
struct SolutionsTabView: View {
    let solutions: [Solution]
    @State private var selection: Int = 0

    var body: some View {
        if solutions.isEmpty {
            Text("No reference solutions available.")
                .font(.callout)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Solution", selection: $selection) {
                    ForEach(Array(solutions.enumerated()), id: \.offset) { idx, solution in
                        Text(tabLabel(idx, solution)).tag(idx)
                    }
                }
                .pickerStyle(.segmented)

                let solution = solutions[min(selection, solutions.count - 1)]
                if let title = solution.title, !title.isEmpty {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                ScrollView([.horizontal, .vertical]) {
                    Text(solution.code)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 160, maxHeight: 320)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func tabLabel(_ index: Int, _ solution: Solution) -> String {
        let sameLabelCount = solutions.prefix(index).filter { $0.languageLabel == solution.languageLabel }.count
        return sameLabelCount == 0 ? solution.languageLabel : "\(solution.languageLabel) \(sameLabelCount + 1)"
    }
}
