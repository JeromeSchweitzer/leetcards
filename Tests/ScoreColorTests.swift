import Foundation
import Testing
@testable import LeetCards

@Suite("Score color spectrum")
struct ScoreColorTests {

    @Test("Hue runs red (0) → green (~0.33) across the score range")
    func endpoints() {
        #expect(Palette.scoreHue(0) == 0)
        #expect(abs(Palette.scoreHue(100) - 0.33) < 0.0001)
    }

    @Test("Midpoint sits between the endpoints (amber range)")
    func midpoint() {
        let mid = Palette.scoreHue(50)
        #expect(mid > Palette.scoreHue(0))
        #expect(mid < Palette.scoreHue(100))
    }

    @Test("Out-of-range scores clamp")
    func clamping() {
        #expect(Palette.scoreHue(-20) == Palette.scoreHue(0))
        #expect(Palette.scoreHue(150) == Palette.scoreHue(100))
    }

    @Test("Hue is monotonically non-decreasing in score")
    func monotonic() {
        let hues = stride(from: 0, through: 100, by: 10).map(Palette.scoreHue)
        #expect(hues == hues.sorted())
    }
}
