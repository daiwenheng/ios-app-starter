import SwiftUI
import UniformTypeIdentifiers

/// 书架:列出所有书,支持导入 txt、滑动删除。
struct ContentView: View {
    @Environment(LibraryStore.self) private var library
    @State private var showingImporter = false
    @State private var isImporting = false
    @State private var importMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if library.books.isEmpty {
                    ContentUnavailableView {
                        Label("书架是空的", systemImage: "books.vertical")
                    } description: {
                        Text("点右上角的 + 导入 txt 小说")
                    }
                } else {
                    bookList
                }
            }
            .navigationTitle("小说阅读器")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingImporter = true
                    } label: {
                        Label("导入小说", systemImage: "plus")
                    }
                    .accessibilityIdentifier("importButton")
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let book = library.book(id: id) {
                    ChapterListView(book: book)
                } else {
                    ContentUnavailableView("这本书已被删除", systemImage: "book.closed")
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.plainText],
                allowsMultipleSelection: true
            ) { result in
                handleImport(result)
            }
            .overlay {
                if isImporting {
                    ProgressView("正在导入…")
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .alert("导入结果", isPresented: alertBinding) {
                Button("好", role: .cancel) {}
            } message: {
                Text(importMessage ?? "")
            }
        }
    }

    private var bookList: some View {
        List {
            ForEach(library.books) { book in
                NavigationLink(value: book.id) {
                    BookRow(book: book, progress: library.progress(for: book.id))
                }
            }
            .onDelete { offsets in
                library.remove(at: offsets)
            }
        }
        .accessibilityIdentifier("bookList")
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { importMessage != nil },
            set: { isPresented in
                if !isPresented { importMessage = nil }
            }
        )
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importMessage = error.localizedDescription
        case .success(let urls):
            guard !urls.isEmpty else { return }
            isImporting = true
            Task {
                var imported = 0
                var failures: [String] = []
                for url in urls {
                    do {
                        let book = try await Task.detached(priority: .userInitiated) {
                            try TextBookParser.importBook(from: url)
                        }.value
                        library.add(book)
                        imported += 1
                    } catch {
                        failures.append("\(url.lastPathComponent):\(error.localizedDescription)")
                    }
                }
                isImporting = false
                var lines: [String] = []
                if imported > 0 { lines.append("已导入 \(imported) 本书。") }
                lines.append(contentsOf: failures)
                importMessage = lines.joined(separator: "\n")
            }
        }
    }
}
