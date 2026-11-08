import SwiftUI

/// 一本书的目录,顶部有"继续阅读"。
struct ChapterListView: View {
    @Environment(LibraryStore.self) private var library
    let book: Book

    var body: some View {
        let saved = library.progress(for: book.id)?.clamped(chapterCount: book.chapters.count)

        List {
            if let saved {
                Section {
                    NavigationLink(
                        value: ReaderRoute(
                            bookID: book.id,
                            chapterIndex: saved.chapterIndex,
                            paragraphIndex: saved.paragraphIndex
                        )
                    ) {
                        Label("继续阅读:\(book.chapters[saved.chapterIndex].title)", systemImage: "book")
                    }
                    .accessibilityIdentifier("continueReading")
                }
            }

            Section("目录(共 \(book.chapters.count) 章)") {
                ForEach(Array(book.chapters.enumerated()), id: \.element.id) { index, chapter in
                    NavigationLink(
                        value: ReaderRoute(bookID: book.id, chapterIndex: index, paragraphIndex: 0)
                    ) {
                        HStack {
                            Text(chapter.title)
                            Spacer()
                            if index == saved?.chapterIndex {
                                Image(systemName: "bookmark.fill")
                                    .foregroundStyle(.tint)
                                    .accessibilityLabel("上次读到这里")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: ReaderRoute.self) { route in
            if let current = library.book(id: route.bookID) {
                ReaderView(
                    book: current,
                    chapterIndex: route.chapterIndex,
                    paragraphIndex: route.paragraphIndex
                )
            } else {
                ContentUnavailableView("这本书已被删除", systemImage: "book.closed")
            }
        }
    }
}
