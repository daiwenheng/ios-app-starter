import SwiftUI

/// 阅读页:滚动阅读一章,点一下屏幕呼出/收起上下菜单,可以直接编辑正文。
struct ReaderView: View {
    let bookID: UUID

    @Environment(LibraryStore.self) private var library
    @Environment(ReaderSettingsStore.self) private var settingsStore
    @Environment(ToastCenter.self) private var toast
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var chapterIndex = 0
    @State private var startBlock = 0
    @State private var scrollID: Int?
    @State private var didLoad = false
    @State private var barsVisible = true
    @State private var isEditing = false
    @State private var editText = ""
    @State private var showingCatalog = false
    @State private var showingSettings = false
    @State private var showingNote = false
    @State private var noteText = ""

    var body: some View {
        Group {
            if let book = library.book(id: bookID), !book.chapters.isEmpty {
                reader(book)
            } else {
                VStack(spacing: 16) {
                    ContentUnavailableView("这本书已被删除", systemImage: "book.closed")
                    Button("返回书架") { dismiss() }
                        .buttonStyle(OutlineButtonStyle())
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear(perform: loadInitial)
        .onDisappear { commitEdit() }
        .toastOverlay()
    }

    // MARK: - 页面

    private func reader(_ book: Book) -> some View {
        let settings = settingsStore.settings
        let palette = ReaderPalette.resolve(settings.theme, systemIsDark: colorScheme == .dark)
        let index = min(max(chapterIndex, 0), book.chapters.count - 1)
        let chapter = book.chapters[index]

        return ZStack {
            palette.background.ignoresSafeArea()

            if isEditing {
                editor(settings: settings, palette: palette)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ChapterTextView(
                            title: chapter.title,
                            content: chapter.content,
                            settings: settings,
                            palette: palette,
                            bookmarkedBlocks: Set(book.bookmarks.filter { $0.chapterID == chapter.id }.map(\.blockIndex)),
                            notedBlocks: Set(book.notes.filter { $0.chapterID == chapter.id }.map(\.blockIndex))
                        )
                        chapterFooter(index: index, count: book.chapters.count, palette: palette)
                    }
                    .padding(.top, settings.padY + 56)
                    .padding(.bottom, settings.padY + 96)
                }
                .scrollPosition(id: $scrollID, anchor: .top)
                .id(chapter.id)
                .task(id: chapter.id) { await scrollToStart(blockCount: ReaderText.paragraphs(from: chapter.content).count + 1) }
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) { barsVisible.toggle() }
                }
            }
        }
        .overlay(alignment: .top) {
            if barsVisible || isEditing { topBar(book: book, index: index, palette: palette) }
        }
        .overlay(alignment: .bottom) {
            if barsVisible && !isEditing {
                bottomBar(count: book.chapters.count, index: index, palette: palette)
            }
        }
        .statusBarHidden(!barsVisible && !isEditing)
        .onChange(of: scrollID) { _, newValue in
            guard let newValue, !isEditing else { return }
            library.saveProgress(ReadingProgress(chapterIndex: index, paragraphIndex: newValue), for: bookID)
        }
        .sheet(isPresented: $showingCatalog) {
            CatalogView(
                bookID: bookID,
                currentChapter: index,
                onJump: { chapter, block in go(to: chapter, block: block) },
                onCurrentChapterMoved: { newIndex in chapterIndex = newIndex }
            )
        }
        .sheet(isPresented: $showingSettings) {
            ReaderSettingsView()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingNote) {
            noteSheet(book: book, index: index)
        }
    }

    private func chapterFooter(index: Int, count: Int, palette: ReaderPalette) -> some View {
        HStack(spacing: 12) {
            Button("上一章") { previousChapter() }
                .disabled(index == 0)
            Button("下一章") { nextChapter() }
                .disabled(index == count - 1)
        }
        .buttonStyle(OutlineButtonStyle())
        .padding(.top, 36)
        .frame(maxWidth: .infinity)
        .opacity(0.9)
    }

    private func editor(settings: ReaderSettings, palette: ReaderPalette) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("编辑中:段与段之间空一行,写完点右上角“保存”")
                .font(.system(size: 12))
                .foregroundStyle(palette.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 64)
                .padding(.bottom, 6)
            TextEditor(text: $editText)
                .font(AppFont.reading(settings.fontSize, bold: settings.bold))
                .foregroundStyle(palette.text)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .accessibilityIdentifier("chapterEditor")
        }
    }

    // MARK: - 上下菜单

    private func topBar(book: Book, index: Int, palette: ReaderPalette) -> some View {
        HStack(spacing: 14) {
            Button {
                commitEdit()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
            }
            .accessibilityLabel("返回书架")

            VStack(alignment: .leading, spacing: 1) {
                Text(book.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text("第 \(index + 1) / \(book.chapters.count) 章")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.secondary)
            }
            Spacer(minLength: 0)

            Button(isEditing ? "保存" : "编辑") {
                isEditing ? commitEdit(announce: true) : beginEdit(book: book, index: index)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Palette.accent)
            .accessibilityIdentifier("editButton")

            if !isEditing {
                Menu {
                    Button("在这里加书签", systemImage: "bookmark") { addBookmark(book: book, index: index) }
                    Button("在这里写笔记", systemImage: "square.and.pencil") {
                        noteText = ""
                        showingNote = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .accessibilityLabel("更多")
            }
        }
        .foregroundStyle(palette.text)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(palette.bar.ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.line.opacity(0.6)).frame(height: 0.5) }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func bottomBar(count: Int, index: Int, palette: ReaderPalette) -> some View {
        HStack {
            barButton("chevron.left.2", "上一章", enabled: index > 0, action: previousChapter)
            barButton("list.bullet", "目录", enabled: true) {
                commitEdit()
                showingCatalog = true
            }
            .accessibilityIdentifier("catalogButton")
            barButton("textformat.size", "设置", enabled: true) { showingSettings = true }
                .accessibilityIdentifier("settingsButton")
            barButton("chevron.right.2", "下一章", enabled: index < count - 1, action: nextChapter)
        }
        .foregroundStyle(palette.text)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity)
        .background(palette.bar.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(Palette.line.opacity(0.6)).frame(height: 0.5) }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func barButton(_ icon: String, _ label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 18))
                Text(label).font(.system(size: 11))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
    }

    private func noteSheet(book: Book, index: Int) -> some View {
        let block = currentBlock(in: book, index: index)
        return NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                if !block.excerpt.isEmpty {
                    Text(block.excerpt)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.inkSoft)
                        .padding(.leading, 10)
                        .overlay(alignment: .leading) {
                            Rectangle().fill(Palette.accent).frame(width: 3)
                        }
                }
                TextEditor(text: $noteText)
                    .font(.system(size: 16))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Palette.surface))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.line, lineWidth: 1))
                    .frame(minHeight: 140)
                Spacer(minLength: 0)
            }
            .padding(20)
            .background(Palette.mist)
            .navigationTitle("写笔记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showingNote = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        var saved = false
                        library.update(bookID: bookID) {
                            saved = $0.addNote(
                                chapterIndex: index,
                                blockIndex: block.index,
                                quote: block.excerpt,
                                text: noteText
                            )
                        }
                        toast.show(saved ? "笔记已保存" : "笔记内容不能为空")
                        if saved { showingNote = false }
                    }
                }
            }
        }
        .tint(Palette.accent)
        .presentationDetents([.medium])
    }

    // MARK: - 行为

    private func loadInitial() {
        guard !didLoad, let book = library.book(id: bookID) else { return }
        didLoad = true
        if let saved = library.progress(for: bookID)?.clamped(chapterCount: book.chapters.count) {
            chapterIndex = saved.chapterIndex
            startBlock = saved.paragraphIndex
        }
    }

    private func scrollToStart(blockCount: Int) async {
        let target = min(max(startBlock, 0), max(blockCount - 1, 0))
        startBlock = 0
        try? await Task.sleep(nanoseconds: 80_000_000)
        scrollID = target
        if target == 0 {
            // 进度记在章节开头,不需要再滚动。
            library.saveProgress(ReadingProgress(chapterIndex: chapterIndex, paragraphIndex: 0), for: bookID)
        }
    }

    private func go(to chapter: Int, block: Int) {
        commitEdit()
        guard let book = library.book(id: bookID), !book.chapters.isEmpty else { return }
        let target = min(max(chapter, 0), book.chapters.count - 1)
        startBlock = block
        scrollID = nil
        chapterIndex = target
    }

    private func previousChapter() {
        if chapterIndex > 0 {
            go(to: chapterIndex - 1, block: 0)
        } else {
            toast.show("已经是第一章了")
        }
    }

    private func nextChapter() {
        let count = library.book(id: bookID)?.chapters.count ?? 0
        if chapterIndex < count - 1 {
            go(to: chapterIndex + 1, block: 0)
        } else {
            toast.show("已经是最后一章了")
        }
    }

    private func beginEdit(book: Book, index: Int) {
        editText = ReaderText.editableText(from: book.chapters[index].content)
        isEditing = true
        toast.show("已开启编辑")
    }

    /// 编辑中就把输入框里的文字存回当前章节;没在编辑什么都不做。
    private func commitEdit(announce: Bool = false) {
        guard isEditing else { return }
        let index = chapterIndex
        let text = ReaderText.content(fromEditable: editText)
        library.update(bookID: bookID) { book in
            guard book.chapters.indices.contains(index) else { return }
            book.chapters[index].content = text
        }
        startBlock = scrollID ?? 0
        isEditing = false
        if announce { toast.show("内容已保存") }
    }

    private func currentBlock(in book: Book, index: Int) -> (index: Int, excerpt: String) {
        let paragraphs = ReaderText.paragraphs(from: book.chapters[index].content)
        let block = min(max(scrollID ?? 0, 0), paragraphs.count)
        if block == 0 { return (0, ReaderText.excerpt(book.chapters[index].title)) }
        return (block, ReaderText.excerpt(paragraphs[block - 1]))
    }

    private func addBookmark(book: Book, index: Int) {
        let block = currentBlock(in: book, index: index)
        var added = false
        library.update(bookID: bookID) {
            added = $0.addBookmark(chapterIndex: index, blockIndex: block.index, excerpt: block.excerpt)
        }
        toast.show(added ? "已加书签" : "这里已经有书签了")
    }
}
