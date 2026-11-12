import SwiftUI

/// 一章正文:标题 + 段落,按阅读设置排版。放在 ScrollView 里,每个块的 id 就是它的序号(0 是标题)。
/// 单独成一个视图,滚动时(只有滚动位置在变)不会重新分段。
struct ChapterTextView: View {
    let title: String
    let content: String
    let settings: ReaderSettings
    let palette: ReaderPalette
    let bookmarkedBlocks: Set<Int>
    let notedBlocks: Set<Int>

    private var textColor: Color {
        if palette.isDark || settings.theme == .eyeCare { return palette.text }
        return Color(hexString: settings.textColorHex)
    }

    var body: some View {
        let blocks = ReaderText.blocks(title: title, content: content)
        LazyVStack(alignment: .leading, spacing: settings.paragraphSpacing) {
            ForEach(blocks) { block in
                blockView(block)
                    .id(block.id)
            }
        }
        .scrollTargetLayout()
        .padding(.horizontal, settings.padX)
    }

    @ViewBuilder
    private func blockView(_ block: ReaderBlock) -> some View {
        if block.isTitle {
            Text(block.text)
                .font(AppFont.display(settings.fontSize * 1.4))
                .foregroundStyle(textColor)
                .padding(.bottom, settings.fontSize * 0.6)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(attributed(block.text))
                .font(AppFont.reading(settings.fontSize, bold: settings.bold))
                .kerning(settings.letterSpacing)
                .lineSpacing(settings.extraLineSpacing)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .topTrailing) { marks(for: block.id) }
        }
    }

    @ViewBuilder
    private func marks(for index: Int) -> some View {
        HStack(spacing: 4) {
            if notedBlocks.contains(index) {
                Image(systemName: "square.and.pencil")
            }
            if bookmarkedBlocks.contains(index) {
                Image(systemName: "bookmark.fill")
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(Palette.accent)
        .offset(x: 2, y: -4)
        .accessibilityHidden(true)
    }

    private func attributed(_ paragraph: String) -> AttributedString {
        var result = AttributedString()
        var lead = AttributedString("\u{3000}\u{3000}")
        lead.foregroundColor = textColor
        result.append(lead)
        let dialogueColor = Color(hexString: settings.dialogueColorHex, fallback: 0x5B8C6F)
        for segment in DialogueHighlighter.segments(in: paragraph) {
            var piece = AttributedString(segment.text)
            piece.foregroundColor = (segment.isDialogue && settings.dialogueHighlight) ? dialogueColor : textColor
            result.append(piece)
        }
        return result
    }
}
