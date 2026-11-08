import SwiftUI

/// 阅读页:滚动阅读、上一章/下一章、阅读设置,并自动记住阅读位置。
struct ReaderView: View {
    @Environment(LibraryStore.self) private var library
    @AppStorage(ReaderStyle.fontSizeKey) private var fontSize = ReaderStyle.defaultFontSize
    @AppStorage(ReaderStyle.lineSpacingKey) private var lineSpacing = ReaderStyle.defaultLineSpacing
    @AppStorage(ReaderStyle.themeKey) private var themeRaw = ReaderTheme.system.rawValue

    let book: Book
    @State private var chapterIndex: Int
    @State private var topBlock: Int?
    @State private var showingSettings = false

    init(book: Book, chapterIndex: Int, paragraphIndex: Int) {
        self.book = book
        let lastIndex = max(book.chapters.count - 1, 0)
        _chapterIndex = State(initialValue: min(max(chapterIndex, 0), lastIndex))
        _topBlock = State(initialValue: max(paragraphIndex, 0))
    }

    private var theme: ReaderTheme {
        ReaderTheme(rawValue: themeRaw) ?? .system
    }

    var body: some View {
        Group {
            if book.chapters.isEmpty {
                ContentUnavailableView("这本书还没有内容", systemImage: "book.closed")
            } else {
                reader
            }
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
        .preferredColorScheme(theme.colorScheme)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "textformat.size")
                }
                .accessibilityLabel("阅读设置")
                .accessibilityIdentifier("readerSettingsButton")
            }
        }
        .sheet(isPresented: $showingSettings) {
            ReaderSettingsView()
                .presentationDetents([.height(360), .large])
        }
        .onChange(of: topBlock) { _, _ in
            saveProgress()
        }
        .onAppear {
            saveProgress()
        }
    }

    private var reader: some View {
        let chapter = book.chapters[chapterIndex]
        let blocks = ReaderText.blocks(title: chapter.title, content: chapter.content)

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                LazyVStack(alignment: .leading, spacing: lineSpacing * 1.5) {
                    ForEach(blocks) { block in
                        if block.isTitle {
                            Text(block.text)
                                .font(.system(size: fontSize + 5, weight: .bold))
                                .padding(.bottom, 8)
                        } else {
                            Text("\u{3000}\u{3000}" + block.text)
                                .font(.system(size: fontSize))
                                .lineSpacing(lineSpacing)
                        }
                    }
                }
                .scrollTargetLayout()

                chapterNavigation
                    .padding(.top, 32)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(theme.foreground)
        }
        .scrollPosition(id: $topBlock, anchor: .top)
        .id(chapterIndex)
    }

    private var chapterNavigation: some View {
        HStack {
            Button("上一章") {
                go(to: chapterIndex - 1)
            }
            .disabled(chapterIndex <= 0)
            .accessibilityIdentifier("previousChapter")

            Spacer()

            Text("\(chapterIndex + 1) / \(book.chapters.count)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()

            Button("下一章") {
                go(to: chapterIndex + 1)
            }
            .disabled(chapterIndex >= book.chapters.count - 1)
            .accessibilityIdentifier("nextChapter")
        }
        .buttonStyle(.bordered)
    }

    private func go(to index: Int) {
        guard book.chapters.indices.contains(index) else { return }
        chapterIndex = index
        topBlock = 0
        saveProgress()
    }

    private func saveProgress() {
        guard !book.chapters.isEmpty else { return }
        library.saveProgress(
            ReadingProgress(chapterIndex: chapterIndex, paragraphIndex: topBlock ?? 0),
            for: book.id
        )
    }
}
