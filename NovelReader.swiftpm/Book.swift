import Foundation

/// 一本书。可持久化(Codable);`id` 在书的整个生命周期内保持不变。
/// 相等和哈希只看 `id`,避免对整本书的正文做哈希。
struct Book: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var author: String
    var desc: String
    /// 封面图片数据(JPEG/PNG);为 nil 时用自动生成的文字封面。
    var coverData: Data?
    var chapters: [Chapter]
    var createdAt: Date
    var bookmarks: [Bookmark]
    var notes: [Note]

    init(
        id: UUID = UUID(),
        title: String,
        author: String,
        desc: String = "",
        coverData: Data? = nil,
        chapters: [Chapter],
        createdAt: Date = Date(),
        bookmarks: [Bookmark] = [],
        notes: [Note] = []
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.desc = desc
        self.coverData = coverData
        self.chapters = chapters
        self.createdAt = createdAt
        self.bookmarks = bookmarks
        self.notes = notes
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, author, desc, coverData, chapters, createdAt, bookmarks, notes
    }

    /// 兼容旧版 library.json:后来新增的字段缺失时用默认值。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        author = try container.decode(String.self, forKey: .author)
        desc = try container.decodeIfPresent(String.self, forKey: .desc) ?? ""
        coverData = try container.decodeIfPresent(Data.self, forKey: .coverData)
        chapters = try container.decode([Chapter].self, forKey: .chapters)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
            ?? Date(timeIntervalSince1970: 0)
        bookmarks = try container.decodeIfPresent([Bookmark].self, forKey: .bookmarks) ?? []
        notes = try container.decodeIfPresent([Note].self, forKey: .notes) ?? []
    }

    static func == (lhs: Book, rhs: Book) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct Chapter: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var content: String

    init(id: UUID = UUID(), title: String, content: String) {
        self.id = id
        self.title = title
        self.content = content
    }
}
