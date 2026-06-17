import SwiftUI

/// The root deck screen: the current flashcard, previous/next navigation, a
/// progress pill, the deck menu, and a button into the Problems browser.
struct DeckView: View {
    @Bindable var store: DeckStore
    /// Non-nil when on-device grading is unavailable (using the manual/mock path).
    let graderNotice: String?

    @Environment(\.palette) private var palette
    @AppStorage("theme") private var themeRaw = AppTheme.dark.rawValue
    @State private var showingProblems = false

    var body: some View {
        NavigationStack {
            Group {
                if store.isFinished {
                    DeckSummaryView(store: store) { showingProblems = true }
                } else if let problem = store.current, let card = store.currentCard {
                    FlashcardView(problem: problem, store: store, model: card)
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
                ToolbarItem {
                    Button {
                        showingProblems = true
                    } label: {
                        Label("Problems", systemImage: "list.bullet.rectangle")
                    }
                }
                ToolbarItem {
                    deckMenu
                }
            }
            .navigationDestination(isPresented: $showingProblems) {
                ProblemListView(store: store)
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
                    Label("All in deck", systemImage: "square.stack")
                }
                Button {
                    store.query.filter = .failedOrDue
                } label: {
                    Label("Review failed", systemImage: "exclamationmark.arrow.circlepath")
                }
            }
            Section("Theme") {
                ForEach(AppTheme.allCases) { theme in
                    Button {
                        themeRaw = theme.rawValue
                    } label: {
                        Label(theme.displayName, systemImage: theme.symbol)
                    }
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
            .disabled(!store.hasPrevious || store.isReviewing)

            Spacer()

            // Progress pill (single, fully-controlled — no toolbar double border).
            Text("\(store.progressText)  ·  \(store.solvedCount) passed")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Layout.pillHPadding)
                .padding(.vertical, Layout.pillVPadding)
                .background(palette.pill, in: Capsule())

            Spacer()

            Button {
                store.goNext()
            } label: {
                Label("Next", systemImage: "chevron.right")
            }
            .disabled(!store.hasNext || store.isReviewing)
        }
        .padding(.horizontal, Layout.navBarHPadding)
        .padding(.vertical, Layout.navBarVPadding)
        .background(.bar)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Your deck is empty", systemImage: "tray")
        } description: {
            Text(store.query.filter == .failedOrDue
                 ? "No failed cards — switch to All in deck from the deck menu."
                 : "Add problems from the Problems list to start studying.")
        } actions: {
            Button("Browse Problems") { showingProblems = true }
                .buttonStyle(.borderedProminent)
        }
    }
}
