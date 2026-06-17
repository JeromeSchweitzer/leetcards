import SwiftUI

/// A block of parsed markdown. Block parsing is kept pure (no SwiftUI) so it can
/// be unit-tested directly; `MarkdownView` only handles rendering.
enum MarkdownBlock: Equatable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case codeBlock(String)
    case bulleted([String])
    case numbered([String])
}

/// Split markdown text into block-level elements.
///
/// Handles fenced code blocks (```` ``` ````, contents kept verbatim — markdown
/// inside is *not* interpreted), ATX headings (`#`..`######`), `-`/`*`/`+`
/// bullet lists, `1.` ordered lists, and blank-line-separated paragraphs.
func parseMarkdownBlocks(_ text: String) -> [MarkdownBlock] {
    var blocks: [MarkdownBlock] = []
    let lines = text.components(separatedBy: "\n")
    var i = 0

    func isBullet(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        return t == "-" || t == "*" || t == "+"
            || t.hasPrefix("- ") || t.hasPrefix("* ") || t.hasPrefix("+ ")
    }
    func isNumbered(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard let dot = t.firstIndex(of: ".") else { return false }
        let prefix = t[t.startIndex..<dot]
        return !prefix.isEmpty && prefix.allSatisfy(\.isNumber) && t[dot...].hasPrefix(". ")
    }
    func listItemText(_ line: String) -> String {
        let t = line.trimmingCharacters(in: .whitespaces)
        if let dot = t.firstIndex(of: "."), isNumbered(line) {
            return String(t[t.index(after: dot)...]).trimmingCharacters(in: .whitespaces)
        }
        return String(t.dropFirst(1)).trimmingCharacters(in: .whitespaces)
    }

    while i < lines.count {
        let raw = lines[i]
        let line = raw.trimmingCharacters(in: .whitespaces)

        // Blank line — skip.
        if line.isEmpty {
            i += 1
            continue
        }

        // Fenced code block.
        if line.hasPrefix("```") {
            var code: [String] = []
            i += 1
            while i < lines.count, !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                code.append(lines[i])
                i += 1
            }
            if i < lines.count { i += 1 } // consume closing fence
            blocks.append(.codeBlock(code.joined(separator: "\n")))
            continue
        }

        // ATX heading.
        if line.hasPrefix("#") {
            let hashes = line.prefix { $0 == "#" }.count
            if hashes <= 6, line.dropFirst(hashes).hasPrefix(" ") {
                let text = line.dropFirst(hashes).trimmingCharacters(in: .whitespaces)
                blocks.append(.heading(level: hashes, text: text))
                i += 1
                continue
            }
        }

        // Bulleted list (consecutive bullet lines).
        if isBullet(raw) {
            var items: [String] = []
            while i < lines.count, isBullet(lines[i]) {
                items.append(listItemText(lines[i]))
                i += 1
            }
            blocks.append(.bulleted(items))
            continue
        }

        // Numbered list.
        if isNumbered(raw) {
            var items: [String] = []
            while i < lines.count, isNumbered(lines[i]) {
                items.append(listItemText(lines[i]))
                i += 1
            }
            blocks.append(.numbered(items))
            continue
        }

        // Paragraph — always consume the current line first (it has already
        // been ruled out as blank/heading/code/list above), guaranteeing forward
        // progress, then gather continuation lines until a blank/block starter.
        var para: [String] = [line]
        i += 1
        while i < lines.count {
            let l = lines[i]
            let t = l.trimmingCharacters(in: .whitespaces)
            if t.isEmpty || t.hasPrefix("```") || t.hasPrefix("#") || isBullet(l) || isNumbered(l) {
                break
            }
            para.append(t)
            i += 1
        }
        blocks.append(.paragraph(para.joined(separator: " ")))
    }

    return blocks
}

/// Renders markdown text block-by-block using only SwiftUI (no dependencies).
struct MarkdownView: View {
    let text: String
    private var blocks: [MarkdownBlock] { parseMarkdownBlocks(text) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                view(for: block)
            }
        }
    }

    @ViewBuilder
    private func view(for block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(text)
                .font(headingFont(level))
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .paragraph(let text):
            Text(inline(text))
                .frame(maxWidth: .infinity, alignment: .leading)
        case .codeBlock(let code):
            Text(code)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
        case .bulleted(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    listRow(marker: "•", text: item)
                }
            }
        case .numbered(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    listRow(marker: "\(idx + 1).", text: item)
                }
            }
        }
    }

    private func listRow(marker: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(marker).foregroundStyle(.secondary)
            Text(inline(text)).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: .title2
        case 2: .title3
        default: .headline
        }
    }

    /// Parse inline markdown (bold, `code`, links) for a single block of text.
    /// Falls back to plain text if parsing fails.
    private func inline(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }
}

/// Shared layout constants. Referenced (not magic numbers) so spacing can be
/// tripwire-tested and tuned in one place.
enum Layout {
    /// Horizontal inset for the bottom Prev/Next navigation bar.
    static let navBarHPadding: CGFloat = 24
    /// Vertical inset for the bottom Prev/Next navigation bar.
    static let navBarVPadding: CGFloat = 12
    /// Horizontal padding inside the toolbar progress pill.
    static let pillHPadding: CGFloat = 12
    /// Vertical padding inside the toolbar progress pill.
    static let pillVPadding: CGFloat = 6
}
