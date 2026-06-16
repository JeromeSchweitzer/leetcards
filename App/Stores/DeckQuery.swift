import Foundation

/// Describes *which* problems make up the deck and in *what order*.
///
/// Order and filter are plain data, so today's shuffle/sequential + failed-or-due
/// queue — and tomorrow's tag/difficulty filters or a no-grade reveal mode — are
/// configuration changes rather than new control flow in `DeckStore`.
struct DeckQuery: Equatable, Sendable {
    enum Order: Equatable, Sendable {
        case sequential
        /// Deterministic shuffle — the seed makes ordering reproducible (tests
        /// pin a seed; the app seeds randomly per launch).
        case shuffled(seed: UInt64)
    }

    enum Filter: Equatable, Sendable {
        case all
        /// Only problems whose most recent attempt scored below the pass
        /// threshold (the review-failed / due queue).
        case failedOrDue
    }

    var order: Order
    var filter: Filter

    init(order: Order = .shuffled(seed: UInt64.random(in: .min ... .max)), filter: Filter = .all) {
        self.order = order
        self.filter = filter
    }
}

/// A small, fast, *seedable* RNG (SplitMix64) so `.shuffled(seed:)` is
/// reproducible. `SystemRandomNumberGenerator` can't be seeded, which is why
/// this exists.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // Avoid an all-zero state.
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
