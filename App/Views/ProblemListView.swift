import SwiftUI

/// LeetCode-style problem browser: filter by search/difficulty/tags, see your
/// per-problem stats, toggle deck membership (green check), and tap to study.
///
/// Uses a `ScrollView` + `LazyVStack` rather than `List`: on macOS, `List` row
/// selection swallows the first click on in-row buttons (the toggle would only
/// register on every other click), and `List` imposes its own opaque background
/// that ignores the theme.
struct ProblemListView: View {
    @Bindable var store: DeckStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @State private var criteria = ProblemFilterCriteria()

    private var allTags: [String] {
        Array(Set(store.allProblems.flatMap(\.tags))).sorted()
    }

    private var filtered: [Problem] {
        filterProblems(store.allProblems, criteria: criteria)
            .sorted { ($0.order ?? .max) < ($1.order ?? .max) }
    }

    var body: some View {
        let stats = store.allStats()
        let inDeck = store.selectedProblemIDs()

        ScrollView {
            LazyVStack(spacing: 8, pinnedViews: [.sectionHeaders]) {
                Section {
                    ForEach(filtered) { problem in
                        row(problem, stats: stats[problem.id], inDeck: inDeck.contains(problem.id))
                    }
                } header: {
                    filterBar(shown: filtered.count, inDeck: inDeck.count)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .background(palette.backgroundGradient.ignoresSafeArea())
        .navigationTitle("Problems")
        .searchable(text: $criteria.searchText, prompt: "Search problems")
        .toolbar {
            ToolbarItem {
                Button(role: .destructive) {
                    store.clearDeck()
                } label: {
                    Label("Clear deck", systemImage: "trash")
                }
                .disabled(inDeck.isEmpty)
            }
        }
    }

    // MARK: - Filter bar (pinned)

    private func filterBar(shown: Int, inDeck: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(Difficulty.allCases, id: \.self) { difficulty in
                    chip(difficulty.rawValue,
                         selected: criteria.difficulties.contains(difficulty),
                         color: palette.difficultyColor(difficulty)) {
                        toggle(&criteria.difficulties, difficulty)
                    }
                }
                tagMenu
                Spacer()
            }
            Text("\(shown) shown · \(inDeck) in deck")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            // Slightly transparent so the window's translucency shows through,
            // matching the app border.
            Rectangle().fill(.ultraThinMaterial).opacity(0.65)
        }
    }

    private func chip(_ title: String, selected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(selected ? color.opacity(0.25) : Color.secondary.opacity(0.12), in: Capsule())
                .overlay(Capsule().strokeBorder(selected ? color : .clear, lineWidth: 1))
                .foregroundStyle(selected ? color : .secondary)
        }
        .buttonStyle(.plain)
    }

    private var tagMenu: some View {
        Menu {
            if !criteria.tags.isEmpty {
                Button("Clear tags") { criteria.tags.removeAll() }
                Divider()
            }
            ForEach(allTags, id: \.self) { tag in
                Button {
                    toggle(&criteria.tags, tag)
                } label: {
                    Label(tag, systemImage: criteria.tags.contains(tag) ? "checkmark.circle.fill" : "circle")
                }
            }
        } label: {
            let count = criteria.tags.count
            Label(count == 0 ? "Tags" : "Tags (\(count))", systemImage: "tag")
                .font(.caption.weight(.semibold))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    // MARK: - Row

    private func row(_ problem: Problem, stats: ProblemStats?, inDeck: Bool) -> some View {
        HStack(spacing: 12) {
            Button {
                store.toggleDeck(problem.id)
            } label: {
                Image(systemName: inDeck ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(inDeck ? palette.accent : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(inDeck ? "Remove from deck" : "Add to deck")

            Button {
                store.select(problemID: problem.id)
                dismiss()
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            if let number = problem.number {
                                Text("#\(number)").font(.caption).foregroundStyle(.secondary)
                            }
                            Text(problem.title).font(.body.weight(.medium))
                        }
                        if !problem.tags.isEmpty {
                            Text(problem.tags.prefix(3).joined(separator: " · "))
                                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    Spacer()
                    statsView(stats)
                    if let difficulty = problem.difficulty {
                        DifficultyBadge(difficulty: difficulty)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func statsView(_ stats: ProblemStats?) -> some View {
        if let stats, stats.attemptCount > 0 {
            VStack(alignment: .trailing, spacing: 2) {
                if let last = stats.lastScore {
                    Text("Last \(last)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.scoreColor(last))
                }
                Text("\(stats.attemptCount) attempt\(stats.attemptCount == 1 ? "" : "s")")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        } else {
            Text("—").font(.caption).foregroundStyle(.tertiary)
        }
    }

    private func toggle<T: Hashable>(_ set: inout Set<T>, _ value: T) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }
}
