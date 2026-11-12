import Foundation

/// 书签:记住某一章里的某个位置。用章节 id 而不是序号,章节调整顺序后依然有效。
struct Bookmark: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var chapterID: UUID
    /// 阅读页内容块序号:0 是章节标题,1 起是正文段落。
    var blockIndex: Int
    var excerpt: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        chapterID: UUID,
        blockIndex: Int,
        excerpt: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.chapterID = chapterID
        self.blockIndex = blockIndex
        self.excerpt = excerpt
        self.createdAt = createdAt
    }
}

/// 笔记:写在某一章某个位置的一段话,附带当时所在段落的摘录。
struct Note: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var chapterID: UUID
    var blockIndex: Int
    var quote: String
    var text: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        chapterID: UUID,
        blockIndex: Int,
        quote: String,
        text: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.chapterID = chapterID
        self.blockIndex = blockIndex
        self.quote = quote
        self.text = text
        self.createdAt = createdAt
    }
}

extension Book {
    /// 在指定位置加书签;同一章同一位置已有书签时返回 false。
    @discardableResult
    mutating func addBookmark(chapterIndex: Int, blockIndex: Int, excerpt: String, at date: Date = Date()) -> Bool {
        guard chapters.indices.contains(chapterIndex) else { return false }
        let chapterID = chapters[chapterIndex].id
        if bookmarks.contains(where: { $0.chapterID == chapterID && $0.blockIndex == blockIndex }) {
            return false
        }
        bookmarks.append(
            Bookmark(chapterID: chapterID, blockIndex: blockIndex, excerpt: excerpt, createdAt: date)
        )
        return true
    }

    /// 写一条笔记;内容为空(只有空白)时返回 false。
    @discardableResult
    mutating func addNote(chapterIndex: Int, blockIndex: Int, quote: String, text: String, at date: Date = Date()) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, chapters.indices.contains(chapterIndex) else { return false }
        notes.append(
            Note(
                chapterID: chapters[chapterIndex].id,
                blockIndex: blockIndex,
                quote: quote,
                text: trimmed,
                createdAt: date
            )
        )
        return true
    }

    mutating func removeBookmark(id: UUID) {
        bookmarks.removeAll { $0.id == id }
    }

    mutating func removeNote(id: UUID) {
        notes.removeAll { $0.id == id }
    }

    func chapterIndex(of chapterID: UUID) -> Int? {
        chapters.firstIndex { $0.id == chapterID }
    }
}
