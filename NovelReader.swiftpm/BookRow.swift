import SwiftUI

struct BookRow: View {
    let book: Book
    let progress: ReadingProgress?

    var body: some View {
        HStack(spacing: 12) {
            Text(String(book.title.prefix(1)))
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 44, height: 58)
                .background(.tint, in: RoundedRectangle(cornerRadius: 6))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(book.title)
                    .font(.headline)
                Text("\(book.author) · 共 \(book.chapters.count) 章")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let text = progressText {
                    Text(text)
                        .font(.caption)
                        .foregroundStyle(.tint)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var progressText: String? {
        guard let current = progress?.clamped(chapterCount: book.chapters.count) else { return nil }
        return "读到:\(book.chapters[current.chapterIndex].title)"
    }
}
