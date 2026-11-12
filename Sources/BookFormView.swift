import PhotosUI
import SwiftUI

/// 打开"书籍信息"表单的请求:新书(带着导入或新写的章节)或修改已有的书。
struct BookFormRequest: Identifiable {
    let id = UUID()
    var draft: BookDraft
    /// 修改已有书籍时是那本书的 id;新书为 nil。
    var editingBookID: UUID?
}

/// 书籍信息表单:封面、书名、作者、简介。导入、写书、修改信息共用。
struct BookFormView: View {
    let request: BookFormRequest
    /// 新书保存成功后调用。
    var onCreated: (Book) -> Void = { _ in }

    @Environment(LibraryStore.self) private var library
    @Environment(ToastCenter.self) private var toast
    @Environment(\.dismiss) private var dismiss

    @State private var draft: BookDraft
    @State private var pickedItem: PhotosPickerItem?
    @State private var previewID = UUID()

    init(request: BookFormRequest, onCreated: @escaping (Book) -> Void = { _ in }) {
        self.request = request
        self.onCreated = onCreated
        _draft = State(initialValue: request.draft)
    }

    private var isEditing: Bool { request.editingBookID != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    coverSection
                    labeled("书名") {
                        TextField("必填", text: $draft.title)
                            .field()
                            .accessibilityIdentifier("formTitle")
                    }
                    labeled("作者") {
                        TextField("不填就是“\(BookDraft.defaultAuthor)”", text: $draft.author)
                            .field()
                    }
                    labeled("简介") {
                        TextField("不填就是“\(BookDraft.defaultDesc)”", text: $draft.desc, axis: .vertical)
                            .lineLimit(3...6)
                            .field()
                    }
                }
                .padding(20)
            }
            .background(Palette.mist)
            .navigationTitle(isEditing ? "编辑书籍信息" : "新书信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .accessibilityIdentifier("formSave")
                }
            }
            .onChange(of: pickedItem) { _, item in
                guard let item else { return }
                Task { await loadCover(from: item) }
            }
            .toastOverlay()
        }
        .tint(Palette.accent)
    }

    private var coverSection: some View {
        HStack(alignment: .bottom, spacing: 16) {
            BookCoverView(
                bookID: request.editingBookID ?? previewID,
                title: draft.cleanedTitle,
                author: draft.cleanedAuthor,
                image: draft.coverData.flatMap { UIImage(data: $0) }
            )
            .frame(width: 110)

            VStack(alignment: .leading, spacing: 10) {
                PhotosPicker(selection: $pickedItem, matching: .images) {
                    Text(draft.coverData == nil ? "选择封面图片" : "更换封面")
                }
                .buttonStyle(OutlineButtonStyle())

                if draft.coverData != nil {
                    Button("恢复默认封面") {
                        draft.coverData = nil
                        pickedItem = nil
                    }
                    .buttonStyle(OutlineButtonStyle())
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func labeled<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
            content()
        }
    }

    private func loadCover(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            toast.show("读取图片失败")
            return
        }
        guard data.count <= CoverImage.maxFileBytes else {
            toast.show("图片不能超过 5MB")
            return
        }
        guard let normalized = CoverImage.normalized(data) else {
            toast.show("这不是有效的图片")
            return
        }
        draft.coverData = normalized
    }

    private func save() {
        guard draft.canSave else {
            toast.show("请填写书名")
            return
        }
        if let bookID = request.editingBookID {
            library.update(bookID: bookID) { draft.apply(to: &$0) }
            toast.show("已保存")
            dismiss()
        } else if let book = draft.makeBook() {
            library.add(book)
            onCreated(book)
            toast.show("已加入书架")
            dismiss()
        }
    }
}
