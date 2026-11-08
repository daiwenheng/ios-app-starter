import Foundation

/// 一本书。可持久化(Codable);`id` 在书的整个生命周期内保持不变。
/// 相等和哈希只看 `id`,避免对整本书的正文做哈希。
struct Book: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var author: String
    var chapters: [Chapter]

    init(id: UUID = UUID(), title: String, author: String, chapters: [Chapter]) {
        self.id = id
        self.title = title
        self.author = author
        self.chapters = chapters
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
