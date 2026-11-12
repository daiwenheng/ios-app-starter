import SwiftUI
import UniformTypeIdentifiers

/// 备份文件:一段 JSON 数据,可以存成文件,也可以复制到剪贴板。
struct BackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// 备份与恢复:勾选要备份的书,导出成文件或复制;或者从文件、剪贴板恢复。
struct BackupView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(ToastCenter.self) private var toast
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Set<UUID> = []
    @State private var didPreselect = false
    @State private var exportDocument = BackupDocument()
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var pendingRestore: BackupCodec.Restored?
    @State private var showingRestoreAlert = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(library.books) { book in
                        Button {
                            toggle(book.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selected.contains(book.id) ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 20))
                                    .foregroundStyle(selected.contains(book.id) ? Palette.accent : Palette.inkSoft)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(book.title)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Palette.ink)
                                    Text("\(book.author) · \(book.chapters.count) 章")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Palette.inkSoft)
                                }
                                Spacer()
                            }
                        }
                        .listRowBackground(Palette.surface)
                    }
                } header: {
                    HStack {
                        Text("选择要备份的书(已选 \(selected.count) 本)")
                        Spacer()
                        Button("全选") { selected = Set(library.books.map(\.id)) }
                        Button("全不选") { selected = [] }
                    }
                    .textCase(nil)
                    .font(.system(size: 13))
                }

                Section("备份") {
                    Button("导出为文件", action: exportFile)
                        .accessibilityIdentifier("exportBackup")
                    Button("复制到剪贴板", action: copyToPasteboard)
                }
                .listRowBackground(Palette.surface)

                Section {
                    Button("从文件导入") { showingImporter = true }
                    Button("从剪贴板导入", action: importFromPasteboard)
                } header: {
                    Text("恢复")
                } footer: {
                    Text("导入会覆盖当前所有的书。网页版“阅书”导出的备份可以直接导入。")
                }
                .listRowBackground(Palette.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Palette.mist)
            .navigationTitle("备份与恢复")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .fileExporter(
                isPresented: $showingExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "阅书备份"
            ) { result in
                switch result {
                case .success: toast.show("已导出备份")
                case .failure(let error): toast.show("导出失败:\(error.localizedDescription)")
                }
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json, .plainText]) { result in
                importFromFile(result)
            }
            .alert("覆盖当前所有书?", isPresented: $showingRestoreAlert) {
                Button("取消", role: .cancel) { pendingRestore = nil }
                Button("导入", role: .destructive, action: applyRestore)
            } message: {
                Text("将导入 \(pendingRestore?.books.count ?? 0) 本书,当前书架上的书会被替换。")
            }
            .onAppear {
                if !didPreselect {
                    selected = Set(library.books.map(\.id))
                    didPreselect = true
                }
            }
            .toastOverlay()
        }
        .tint(Palette.accent)
    }

    private func toggle(_ id: UUID) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    private func selectedPayload() -> Data? {
        let books = library.books.filter { selected.contains($0.id) }
        guard !books.isEmpty else {
            toast.show("请先勾选要备份的书")
            return nil
        }
        do {
            return try BackupCodec.encode(books: books, progress: library.progress)
        } catch {
            toast.show("打包失败")
            return nil
        }
    }

    private func exportFile() {
        guard let data = selectedPayload() else { return }
        exportDocument = BackupDocument(data: data)
        showingExporter = true
    }

    private func copyToPasteboard() {
        guard let data = selectedPayload() else { return }
        UIPasteboard.general.string = String(decoding: data, as: UTF8.self)
        toast.show("已复制到剪贴板")
    }

    private func importFromPasteboard() {
        guard let text = UIPasteboard.general.string, !text.isEmpty else {
            toast.show("剪贴板里没有内容")
            return
        }
        prepareRestore(from: Data(text.utf8))
    }

    private func importFromFile(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            toast.show("读取失败:\(error.localizedDescription)")
        case .success(let url):
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                toast.show("读取失败")
                return
            }
            prepareRestore(from: data)
        }
    }

    private func prepareRestore(from data: Data) {
        do {
            let restored = try BackupCodec.decode(data)
            guard !restored.books.isEmpty else {
                toast.show("备份里没有书")
                return
            }
            pendingRestore = restored
            showingRestoreAlert = true
        } catch {
            toast.show("解析失败:不是有效的备份数据")
        }
    }

    private func applyRestore() {
        guard let restored = pendingRestore else { return }
        library.replaceAll(books: restored.books, progress: restored.progress)
        pendingRestore = nil
        toast.show("导入成功,共 \(restored.books.count) 本")
        dismiss()
    }
}
