import SwiftUI
import UniformTypeIdentifiers

/// 书架:封面网格、搜索、传 TXT、写书、备份、管理。
struct ContentView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(ToastCenter.self) private var toast

    @State private var path: [UUID] = []
    @State private var query = ""
    @State private var isManaging = false
    @State private var showingImporter = false
    @State private var showingBackup = false
    @State private var isImporting = false
    @State private var formRequest: BookFormRequest?
    @State private var deleteTarget: Book?

    private let columns = [GridItem(.adaptive(minimum: 104, maximum: 150), spacing: 18, alignment: .top)]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    actions
                    searchField
                    if query.isEmpty, let recent = library.mostRecentlyRead {
                        continueBanner(recent)
                    }
                    shelf
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .background(Palette.mist)
            .navigationBarHidden(true)
            .navigationDestination(for: UUID.self) { id in
                ReaderView(bookID: id)
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.plainText],
                allowsMultipleSelection: true
            ) { result in
                handleImport(result)
            }
            .sheet(item: $formRequest) { request in
                BookFormView(request: request)
            }
            .sheet(isPresented: $showingBackup) {
                BackupView()
            }
            .alert(
                "删除这本书?",
                isPresented: $showingDeleteAlert,
                presenting: deleteTarget
            ) { book in
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    library.remove(ids: [book.id])
                    toast.show("已删除")
                }
            } message: { book in
                Text("《\(book.title)》和它的书签、笔记都会被删除,不能恢复。")
            }
            .overlay {
                if isImporting {
                    ProgressView("正在导入…")
                        .padding(24)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 4))
                }
            }
            .toastOverlay()
        }
        .tint(Palette.accent)
    }

    @State private var showingDeleteAlert = false

    // MARK: - 页面部件

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("书架")
                .font(AppFont.display(38))
                .foregroundStyle(Palette.ink)
            Text("\(library.books.count) 本书")
                .font(.system(size: 14))
                .foregroundStyle(Palette.inkSoft)
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button("传 TXT") { showingImporter = true }
                .buttonStyle(SolidButtonStyle(compact: true))
                .accessibilityIdentifier("importButton")
            Button("写书") {
                formRequest = BookFormRequest(
                    draft: BookDraft(chapters: [Chapter(title: "第一章", content: "")])
                )
            }
            .buttonStyle(OutlineButtonStyle())
            Button("备份") { showingBackup = true }
                .buttonStyle(OutlineButtonStyle())
            Spacer(minLength: 0)
            Button(isManaging ? "完成" : "管理") {
                withAnimation(.easeInOut(duration: 0.15)) { isManaging.toggle() }
            }
            .buttonStyle(OutlineButtonStyle(selected: isManaging))
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Palette.inkSoft)
            TextField("搜索书名或作者", text: $query)
                .submitLabel(.search)
        }
        .field()
    }

    private func continueBanner(_ book: Book) -> some View {
        let saved = library.progress(for: book.id)?.clamped(chapterCount: book.chapters.count)
        let index = saved?.chapterIndex ?? 0
        return Button {
            open(book.id)
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("接着读")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.75))
                    Text(book.title)
                        .font(AppFont.display(22))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                    Text(book.chapters[index].title)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.white)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 4).fill(CoverHue.color(for: book.id)))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("continueReading")
    }

    @ViewBuilder
    private var shelf: some View {
        let books = library.sortedBooks(matching: query)
        if library.books.isEmpty {
            emptyState("书架是空的", "点“传 TXT”导入一本小说,或者点“写书”从空白开始。")
        } else if books.isEmpty {
            emptyState("没有找到", "换个书名或作者再搜一次。")
        } else {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 24) {
                ForEach(books) { book in
                    bookCell(book)
                }
            }
            .accessibilityIdentifier("bookGrid")
        }
    }

    private func emptyState(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppFont.display(20))
                .foregroundStyle(Palette.ink)
            Text(detail)
                .font(.system(size: 14))
                .foregroundStyle(Palette.inkSoft)
        }
        .padding(.top, 24)
    }

    private func bookCell(_ book: Book) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            BookCoverView(
                    bookID: book.id,
                    title: book.title,
                    author: book.author,
                    image: library.coverImage(for: book)
                )
                .overlay(alignment: .topTrailing) {
                    if isManaging {
                        HStack(spacing: 6) {
                            badgeButton("pencil", label: "编辑", tint: Palette.accent) {
                                formRequest = BookFormRequest(
                                    draft: BookDraft(editing: book),
                                    editingBookID: book.id
                                )
                            }
                            badgeButton("xmark", label: "删除", tint: Palette.danger) {
                                deleteTarget = book
                                showingDeleteAlert = true
                            }
                        }
                        .padding(6)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if !isManaging { open(book.id) }
                }
                .accessibilityAddTraits(.isButton)

            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                Text(book.author)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(1)
                if let percent = library.progress(for: book.id)?.percent(chapterCount: book.chapters.count) {
                    Text("已读 \(percent)%")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.accent)
                }
            }
        }
    }

    private func badgeButton(_ icon: String, label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.white)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 3).fill(tint))
        }
        .accessibilityLabel(label)
    }

    // MARK: - 操作

    private func open(_ id: UUID) {
        library.markOpened(id)
        path.append(id)
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            toast.show("导入失败:\(error.localizedDescription)")
        case .success(let urls):
            guard !urls.isEmpty else { return }
            isImporting = true
            Task {
                var books: [Book] = []
                var failures: [String] = []
                for url in urls {
                    do {
                        let book = try await Task.detached(priority: .userInitiated) {
                            try TextBookParser.importBook(from: url)
                        }.value
                        books.append(book)
                    } catch {
                        failures.append("\(url.lastPathComponent):\(error.localizedDescription)")
                    }
                }
                isImporting = false
                finishImport(books: books, failures: failures)
            }
        }
    }

    /// 只选了一个文件时先让你确认书名、作者、封面;选了多个就直接放上书架。
    private func finishImport(books: [Book], failures: [String]) {
        if books.count == 1, failures.isEmpty, let book = books.first {
            formRequest = BookFormRequest(
                draft: BookDraft(title: book.title, author: book.author, chapters: book.chapters)
            )
            return
        }
        for book in books { library.add(book) }
        if let failure = failures.first {
            let extra = failures.count > 1 ? "等 \(failures.count) 个文件" : ""
            toast.show("导入失败 \(failure)\(extra)")
        } else if !books.isEmpty {
            toast.show("已导入 \(books.count) 本书")
        }
    }
}
