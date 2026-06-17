import SwiftUI

/// Shown when the user finishes the last card in the deck: a results summary
/// plus next-step actions.
struct DeckSummaryView: View {
    @Bindable var store: DeckStore
    let onBrowse: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        let summary = store.deckSummary()

        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "flag.checkered.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(palette.accent)
                Text("Deck complete!")
                    .font(.largeTitle.weight(.bold))
                Text("You reviewed \(summary.attempted) of \(summary.total) cards.")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                stat("Passed", "\(summary.passed)", color: palette.scoreColor(100))
                stat("Reviewed", "\(summary.attempted)", color: palette.accent)
                stat("Avg score",
                     summary.averageScore.map { "\($0)" } ?? "—",
                     color: summary.averageScore.map(palette.scoreColor) ?? .secondary)
            }

            VStack(spacing: 10) {
                Button {
                    store.query.order = .shuffled(seed: UInt64.random(in: .min ... .max))
                } label: {
                    Label("Study again (shuffled)", systemImage: "arrow.clockwise")
                        .frame(maxWidth: 280)
                }
                .buttonStyle(.borderedProminent)

                if summary.passed < summary.attempted {
                    Button {
                        store.query.filter = .failedOrDue
                    } label: {
                        Label("Review failed", systemImage: "exclamationmark.arrow.circlepath")
                            .frame(maxWidth: 280)
                    }
                    .buttonStyle(.bordered)
                }

                Button {
                    onBrowse()
                } label: {
                    Label("Browse problems", systemImage: "list.bullet.rectangle")
                        .frame(maxWidth: 280)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func stat(_ label: String, _ value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 90)
        .padding(.vertical, 12)
        .background(palette.pill, in: RoundedRectangle(cornerRadius: 12))
    }
}
