import SwiftUI

/// 目录:章节(搜索、排序、编辑)、书签、笔记。
struct CatalogView: View {
    let bookID: UUID
    /// 阅读页当前正在读的章节序号。
    let currentChapter: Int
    /// 点了某一章、书签或笔记,跳到(章节序号, 内容块序号)。
    let onJump: (Int, Int) -> Void
    /// 调整目录顺序或增删章节后,当前章节的序号变了。
    let onCurrentChapterMoved: (Int) -> Void

    @Environment(LibraryStore.self) private var library
    @Environment(ToastCenter.self) private var toast
    @Environment(\.dismiss) private var dismiss

    private enum Tab: String, CaseIterable, Identifiable {
        case chapters = "章节"
        case bookmarks = "书签"
        case notes = "笔记"
        var id: String { rawValue }
    }

    private enum Prompt {
        case insert(after: Int)
        case append
        case rename(Int)
    }

    @State private var tab: Tab = .chapters
    @State private var isEditing = false
    @State private var ascending = true
    @State private var query = ""
    @State private var prompt: Prompt?
    @State private var promptText = ""
    @State private var showingPrompt = false
    @State private var deleteIndex: Int?
    @State private var showingDeleteAlert = false

    var body: some View {
        NavigationStack {
            Group {
                if let book = library.book(id: bookID) {
                    content(book)
                } else {
                    ContentUnavailableView("这本书已被删除", systemImage: "book.closed")
                }
            }
            .background(Palette.mist)
            .navigationTitle("目录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                if tab == .chapters {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(isEditing ? "完成" : "编辑") { isEditing.toggle() }
                            .accessibilityIdentifier("catalogEdit")
                    }
                }
            }
            .alert(promptTitle, isPresented: $showingPrompt) {
                TextField("章节名", text: $promptText)
                Button("取消", role: .cancel) {}
                Button("确定", action: confirmPrompt)
            }
            .alert("删除这一章?", isPresented: $showingDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive, action: confirmDelete)
            } message: {
                Text("这一章的正文、书签和笔记都会被删除,不能恢复。")
            }
            .toastOverlay()
        }
        .tint(Palette.accent)
    }

    // MARK: - 页面

    private func content(_ book: Book) -> some View {
        VStack(spacing: 0) {
            header(book)
            Picker("分类", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
            .onChange(of: tab) { _, newValue in
                if newValue != .chapters { isEditing = false }
            }

            switch tab {
            case .chapters: chapterList(book)
            case .bookmarks: bookmarkList(book)
            case .notes: noteList(book)
            }
        }
    }

    private func header(_ book: Book) -> some View {
        HStack(spacing: 14) {
            BookCoverView(
                bookID: book.id,
                title: book.title,
                author: book.author,
                image: library.coverImage(for: book)
            )
            .frame(width: 54)
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(AppFont.display(20))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                Text("\(book.author) · 共 \(book.chapters.count) 章")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.inkSoft)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
    }

    // MARK: 章节

    private func visibleIndices(_ book: Book) -> [Int] {
        var indices = Array(book.chapters.indices)
        if !ascending { indices.reverse() }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            indices = indices.filter { book.chapters[$0].title.localizedCaseInsensitiveContains(trimmed) }
        }
        return indices
    }

    private func chapterList(_ book: Book) -> some View {
        let indices = visibleIndices(book)
        return List {
            Section {
                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Palette.inkSoft)
                        TextField("搜索章节", text: $query)
                    }
                    .field()
                    Button(ascending ? "正序" : "倒序") { ascending.toggle() }
                        .buttonStyle(OutlineButtonStyle())
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                if indices.isEmpty {
                    Text("没有找到匹配的章节")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.inkSoft)
                        .listRowBackground(Color.clear)
                }
                ForEach(indices, id: \.self) { index in
                    chapterRow(book, index: index)
                        .listRowBackground(Palette.surface)
                }
                if isEditing {
                    Button("+ 添加新章节到末尾") {
                        beginPrompt(.append, text: "新章节")
                    }
                    .listRowBackground(Palette.surface)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func chapterRow(_ book: Book, index: Int) -> some View {
        let isCurrent = index == currentChapter
        return HStack(spacing: 10) {
            Button {
                guard !isEditing else { return }
                dismiss()
                onJump(index, 0)
            } label: {
                HStack {
                    Text(book.chapters[index].title)
                        .font(.system(size: 16, weight: isCurrent ? .bold : .regular))
                        .foregroundStyle(isCurrent ? Palette.accent : Palette.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    if isCurrent && !isEditing {
                        Image(systemName: "checkmark").foregroundStyle(Palette.accent)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isEditing {
                HStack(spacing: 4) {
                    rowIcon("plus", "在后面插入新章", tint: Palette.accent) {
                        beginPrompt(.insert(after: index), text: "新章节")
                    }
                    rowIcon("arrow.up", "上移", tint: Palette.inkSoft) { move(index, by: -1) }
                    rowIcon("arrow.down", "下移", tint: Palette.inkSoft) { move(index, by: 1) }
                    rowIcon("pencil", "改名", tint: Palette.inkSoft) {
                        beginPrompt(.rename(index), text: book.chapters[index].title)
                    }
                    rowIcon("xmark", "删除", tint: Palette.danger) {
                        deleteIndex = index
                        showingDeleteAlert = true
                    }
                }
            }
        }
    }

    private func rowIcon(_ icon: String, _ label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Palette.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: 书签与笔记

    private func bookmarkList(_ book: Book) -> some View {
        let items = book.bookmarks.sorted { $0.createdAt > $1.createdAt }
        return List {
            if items.isEmpty {
                emptyRow("还没有书签。在阅读页点右上角“…”,选“在这里加书签”。")
            }
            ForEach(items) { item in
                if let chapterIndex = book.chapterIndex(of: item.chapterID) {
                    Button {
                        dismiss()
                        onJump(chapterIndex, item.blockIndex)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(book.chapters[chapterIndex].title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Palette.accent)
                            Text(item.excerpt)
                                .font(.system(size: 15))
                                .foregroundStyle(Palette.ink)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .listRowBackground(Palette.surface)
                    .swipeActions {
                        Button("删除", role: .destructive) {
                            library.update(bookID: bookID) { $0.removeBookmark(id: item.id) }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func noteList(_ book: Book) -> some View {
        let items = book.notes.sorted { $0.createdAt > $1.createdAt }
        return List {
            if items.isEmpty {
                emptyRow("还没有笔记。在阅读页点右上角“…”,选“在这里写笔记”。")
            }
            ForEach(items) { item in
                if let chapterIndex = book.chapterIndex(of: item.chapterID) {
                    Button {
                        dismiss()
                        onJump(chapterIndex, item.blockIndex)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(book.chapters[chapterIndex].title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Palette.accent)
                            Text(item.text)
                                .font(.system(size: 15))
                                .foregroundStyle(Palette.ink)
                            if !item.quote.isEmpty {
                                Text(item.quote)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Palette.inkSoft)
                                    .lineLimit(2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .listRowBackground(Palette.surface)
                    .swipeActions {
                        Button("删除", role: .destructive) {
                            library.update(bookID: bookID) { $0.removeNote(id: item.id) }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func emptyRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(Palette.inkSoft)
            .listRowBackground(Color.clear)
    }

    // MARK: - 编辑操作

    private var promptTitle: String {
        switch prompt {
        case .insert: return "插入新章节"
        case .append: return "添加新章节"
        case .rename: return "修改章节名"
        case nil: return ""
        }
    }

    private func beginPrompt(_ newPrompt: Prompt, text: String) {
        prompt = newPrompt
        promptText = text
        showingPrompt = true
    }

    private func confirmPrompt() {
        let title = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, let prompt else {
            toast.show("章节名不能为空")
            return
        }
        switch prompt {
        case .append:
            library.update(bookID: bookID) { $0.appendChapter(title: title) }
            toast.show("已添加")
        case .insert(let index):
            var position = 0
            library.update(bookID: bookID) { position = $0.insertChapter(title: title, after: index) }
            if position <= currentChapter { onCurrentChapterMoved(currentChapter + 1) }
            toast.show("已插入")
        case .rename(let index):
            library.update(bookID: bookID) { $0.renameChapter(at: index, to: title) }
            toast.show("已改名")
        }
        self.prompt = nil
    }

    private func move(_ index: Int, by offset: Int) {
        var target: Int?
        library.update(bookID: bookID) { target = $0.moveChapter(at: index, by: offset) }
        guard let target else {
            toast.show(offset < 0 ? "已经在最前面了" : "已经在最后面了")
            return
        }
        let updated = ChapterIndexMath.afterMove(current: currentChapter, from: index, to: target)
        if updated != currentChapter { onCurrentChapterMoved(updated) }
    }

    private func confirmDelete() {
        guard let index = deleteIndex else { return }
        var deleted = false
        var newCount = 0
        library.update(bookID: bookID) {
            deleted = $0.deleteChapter(at: index)
            newCount = $0.chapters.count
        }
        guard deleted else {
            toast.show("至少要保留一章")
            return
        }
        let updated = ChapterIndexMath.afterDelete(current: currentChapter, deleted: index, newCount: newCount)
        if updated != currentChapter || index == currentChapter { onCurrentChapterMoved(updated) }
        toast.show("已删除")
    }
}
