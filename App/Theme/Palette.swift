import SwiftUI

/// A theme's color set. Views read this from the environment (`\.palette`)
/// instead of hardcoding `.green`/`.orange`, so the whole app restyles by
/// swapping one value.
struct Palette: Sendable {
    let accent: Color
    let easy: Color
    let medium: Color
    let hard: Color
    /// One color = near-solid; two+ = gradient.
    let backgroundColors: [Color]
    /// Fill for the progress pill / chips.
    let pill: Color

    var backgroundGradient: LinearGradient {
        LinearGradient(colors: backgroundColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    func difficultyColor(_ difficulty: Difficulty) -> Color {
        switch difficulty {
        case .easy: easy
        case .medium: medium
        case .hard: hard
        }
    }

    /// Continuous semantic spectrum for a 0…100 score: red → amber → green.
    /// Punchy neon saturation so it reads on dark backgrounds.
    func scoreColor(_ score: Int) -> Color {
        Color(hue: Palette.scoreHue(score), saturation: 0.85, brightness: 1.0)
    }

    /// Pure hue mapping (0 = red … 0.33 = green), clamped. Extracted so it can be
    /// unit-tested without introspecting `Color`.
    static func scoreHue(_ score: Int) -> Double {
        let clamped = Double(max(0, min(100, score)))
        return clamped / 100.0 * 0.33
    }

    static func forTheme(_ theme: AppTheme) -> Palette {
        switch theme {
        case .dark: .midnightNeon
        case .neon: .purpleNebula
        }
    }

    // MARK: - Presets

    /// Near-black background, neon cyan accent.
    static let midnightNeon = Palette(
        accent: Color(red: 0.20, green: 0.95, blue: 0.85),   // neon teal/cyan
        easy: Color(red: 0.30, green: 1.00, blue: 0.62),     // neon green
        medium: Color(red: 1.00, green: 0.78, blue: 0.25),   // neon amber
        hard: Color(red: 1.00, green: 0.33, blue: 0.50),     // neon pink-red
        backgroundColors: [
            Color(red: 0.05, green: 0.06, blue: 0.09),
            Color(red: 0.07, green: 0.05, blue: 0.12),
        ],
        pill: Color(red: 0.20, green: 0.95, blue: 0.85).opacity(0.18)
    )

    /// Deep violet → indigo gradient, electric-purple accent.
    static let purpleNebula = Palette(
        accent: Color(red: 0.70, green: 0.40, blue: 1.00),   // electric purple
        easy: Color(red: 0.50, green: 1.00, blue: 0.78),     // mint
        medium: Color(red: 0.95, green: 0.72, blue: 0.40),   // soft amber
        hard: Color(red: 1.00, green: 0.40, blue: 0.70),     // violet-pink
        backgroundColors: [
            Color(red: 0.10, green: 0.03, blue: 0.22),       // deep indigo-violet
            Color(red: 0.20, green: 0.05, blue: 0.30),       // dark purple
        ],
        pill: Color(red: 0.70, green: 0.40, blue: 1.00).opacity(0.22)
    )
}

// MARK: - Environment

private struct PaletteKey: EnvironmentKey {
    static let defaultValue: Palette = .midnightNeon
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}
