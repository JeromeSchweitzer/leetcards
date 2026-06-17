import Foundation
import Testing
@testable import LeetCards

@Suite("Theme & palette")
struct ThemeTests {

    @Test("AppTheme round-trips its raw value")
    func rawValueRoundTrip() {
        for theme in AppTheme.allCases {
            #expect(AppTheme(rawValue: theme.rawValue) == theme)
        }
        #expect(AppTheme(rawValue: "nonsense") == nil)
    }

    @Test("The neon theme is named Purple Nebula")
    func neonIsPurpleNebula() {
        #expect(AppTheme.neon.displayName == "Purple Nebula")
    }

    @Test("Every theme resolves a palette with a non-empty background")
    func paletteForEachTheme() {
        for theme in AppTheme.allCases {
            let palette = theme.palette
            #expect(!palette.backgroundColors.isEmpty)
        }
    }

    @Test("Difficulty colors are distinct within a palette")
    func difficultyColorsDistinct() {
        let palette = Palette.midnightNeon
        let colors = [palette.difficultyColor(.easy), palette.difficultyColor(.medium), palette.difficultyColor(.hard)]
        #expect(Set(colors.map { "\($0)" }).count == 3)
    }
}
