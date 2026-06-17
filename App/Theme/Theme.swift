import SwiftUI

/// The selectable app theme, persisted via `@AppStorage("theme")`.
///
/// Both themes are vibrant neon-on-dark — `dark` keeps a near-black background
/// with neon accents, `neon` adds a dark pink→purple gradient background.
enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case dark
    case neon

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dark: "Midnight Neon"
        case .neon: "Purple Nebula"
        }
    }

    var symbol: String {
        switch self {
        case .dark: "moon.stars.fill"
        case .neon: "sparkles"
        }
    }

    var palette: Palette { Palette.forTheme(self) }
}
