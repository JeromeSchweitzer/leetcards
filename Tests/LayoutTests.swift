import Foundation
import Testing
@testable import LeetCards

/// Tripwire tests for the spacing fixes (#3 nav buttons, #4 progress pill).
/// True visual spacing is verified by screenshot; these just guard against a
/// regression that zeroes/shrinks the padding.
@Suite("Layout constants")
struct LayoutTests {

    @Test("Nav bar padding stays comfortably off the window edges")
    func navBarPadding() {
        #expect(Layout.navBarHPadding >= 16)
        #expect(Layout.navBarVPadding >= 8)
    }

    @Test("Progress pill has padding around its text")
    func pillPadding() {
        #expect(Layout.pillHPadding >= 8)
        #expect(Layout.pillVPadding >= 4)
    }
}
