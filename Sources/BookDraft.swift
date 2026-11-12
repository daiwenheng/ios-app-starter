import Foundation

/// 书籍信息表单里正在编辑的内容(新导入、新写、修改三种场景共用)。
struct BookDraft: Equatable {
    static let defaultAuthor = "佚名"
    static let defaultDesc = "暂无简介"

    var title: String = ""
    var author: String = ""
    var desc: String = ""
    var coverData: Data?
    /// 新书的章节(导入 txt 或新写一本时带进来);修改已有书籍时为 nil。
    var chapters: [Chapter]?

    init(
        title: String = "",
        author: String = "",
        desc: String = "",
        coverData: Data? = nil,
        chapters: [Chapter]? = nil
    ) {
        self.title = title
        self.author = author
        self.desc = desc
        self.coverData = coverData
        self.chapters = chapters
    }

    /// 修改已有书籍时,用这本书当前的信息填表。
    init(editing book: Book) {
        self.init(title: book.title, author: book.author, desc: book.desc, coverData: book.coverData)
    }

    var cleanedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var cleanedAuthor: String {
        let trimmed = author.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.defaultAuthor : trimmed
    }

    var cleanedDesc: String {
        let trimmed = desc.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.defaultDesc : trimmed
    }

    /// 书名不能为空。
    var canSave: Bool {
        !cleanedTitle.isEmpty
    }

    /// 生成一本新书;书名为空或没有章节数据时返回 nil。
    func makeBook(createdAt: Date = Date()) -> Book? {
        guard canSave, let chapters, !chapters.isEmpty else { return nil }
        return Book(
            title: cleanedTitle,
            author: cleanedAuthor,
            desc: cleanedDesc,
            coverData: coverData,
            chapters: chapters,
            createdAt: createdAt
        )
    }

    /// 把表单内容写回已有书籍(章节、书签、笔记不动)。
    func apply(to book: inout Book) {
        book.title = cleanedTitle
        book.author = cleanedAuthor
        book.desc = cleanedDesc
        book.coverData = coverData
    }
}
