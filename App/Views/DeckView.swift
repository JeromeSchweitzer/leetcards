import SwiftUI

/// The root deck screen: progress, order/queue controls, the current flashcard,
/// and previous/next navigation.
struct DeckView: View {
    @Bindable var store: DeckStore
    /// Non-nil when on-device grading is unavailable (using the manual/mock path).
    let graderNotice: String?

    var body: some View {
        NavigationStack {
            Group {
                if let problem = store.current {
                    FlashcardView(problem: problem, store: store)
                        .id(problem.id)
                } else {
                    emptyState
                }
            }
            .safeAreaInset(edge: .top) {
                if let graderNotice {
                    Label(graderNotice, systemImage: "info.circle")
                        .font(.caption)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.yellow.opacity(0.18))
                }
            }
            .safeAreaInset(edge: .bottom) {
                navigationBar
            }
            .navigationTitle("LeetCards")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("\(store.progressText)  ·  \(store.solvedCount) passed")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                ToolbarItem {
                    deckMenu
                }
            }
        }
    }

    private var deckMenu: some View {
        Menu {
            Section("Order") {
                Button {
                    store.query.order = .shuffled(seed: UInt64.random(in: .min ... .max))
                } label: {
                    Label("Shuffle", systemImage: "shuffle")
                }
                Button {
                    store.query.order = .sequential
                } label: {
                    Label("Sequential", systemImage: "list.number")
                }
            }
            Section("Show") {
                Button {
                    store.query.filter = .all
                } label: {
                    Label("All problems", systemImage: "square.stack")
                }
                Button {
                    store.query.filter = .failedOrDue
                } label: {
                    Label("Review failed", systemImage: "exclamationmark.arrow.circlepath")
                }
            }
        } label: {
            Label("Deck options", systemImage: "ellipsis.circle")
        }
    }

    private var navigationBar: some View {
        HStack {
            Button {
                store.goPrevious()
            } label: {
                Label("Previous", systemImage: "chevron.left")
            }
            .disabled(!store.hasPrevious)

            Spacer()

            Button {
                store.goNext()
            } label: {
                Label("Next", systemImage: "chevron.right")
            }
            .disabled(!store.hasNext)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nothing to review", systemImage: "checkmark.circle")
        } description: {
            Text(store.query.filter == .failedOrDue
                 ? "No failed cards — switch to All problems from the deck menu."
                 : "The deck is empty.")
        }
    }
}
