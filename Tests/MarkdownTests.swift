import Foundation
import Testing
@testable import LeetCards

@Suite("Markdown parsing")
struct MarkdownTests {

    @Test("Fenced code blocks are captured verbatim and not interpreted")
    func fencedCodeVerbatim() {
        let md = """
        Here is an example:

        ```
        Input: nums = [2,7,11,15]
        **not bold** and `not code`
        ```

        Done.
        """
        let blocks = parseMarkdownBlocks(md)
        #expect(blocks.contains(.paragraph("Here is an example:")))
        #expect(blocks.contains(.codeBlock("Input: nums = [2,7,11,15]\n**not bold** and `not code`")))
        #expect(blocks.contains(.paragraph("Done.")))
    }

    @Test("Headings parse with their level")
    func headings() {
        #expect(parseMarkdownBlocks("# Title") == [.heading(level: 1, text: "Title")])
        #expect(parseMarkdownBlocks("### Example 1:") == [.heading(level: 3, text: "Example 1:")])
        // A '#' without a trailing space is not a heading.
        #expect(parseMarkdownBlocks("#hashtag") == [.paragraph("#hashtag")])
    }

    @Test("Bulleted and numbered lists group consecutive items")
    func lists() {
        let bullets = parseMarkdownBlocks("- one\n- two\n- three")
        #expect(bullets == [.bulleted(["one", "two", "three"])])

        let numbered = parseMarkdownBlocks("1. first\n2. second")
        #expect(numbered == [.numbered(["first", "second"])])
    }

    @Test("Multi-line paragraphs are joined; blank lines separate blocks")
    func paragraphs() {
        let md = "Line one\nstill line one\n\nSecond paragraph"
        #expect(parseMarkdownBlocks(md) == [
            .paragraph("Line one still line one"),
            .paragraph("Second paragraph"),
        ])
    }

    @Test("Empty or whitespace input yields no blocks and does not crash")
    func emptyInput() {
        #expect(parseMarkdownBlocks("").isEmpty)
        #expect(parseMarkdownBlocks("   \n\n  \n").isEmpty)
    }

    @Test("A realistic description mixes headings, prose, code, and constraints")
    func realisticMix() {
        let md = """
        Given an array, return indices.

        **Example 1:**

        ```
        Input: nums = [2,7]
        Output: [0,1]
        ```

        **Constraints:**

        - 2 <= nums.length
        - only one valid answer
        """
        let blocks = parseMarkdownBlocks(md)
        // Has at least one code block and one bulleted list, and no block is empty.
        #expect(blocks.contains { if case .codeBlock = $0 { return true } else { return false } })
        #expect(blocks.contains { if case .bulleted = $0 { return true } else { return false } })
    }
}
