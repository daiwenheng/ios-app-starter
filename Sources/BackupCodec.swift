import Foundation

/// 备份文件的编码与解码。格式和原网页版(阅书)的备份 JSON 兼容:
/// 网页版导出的文件可以直接导入;这里导出的文件在原有字段之外多带了书签和笔记。
enum BackupCodec {
    enum BackupError: LocalizedError, Equatable {
        case invalidFormat

        var errorDescription: String? {
            switch self {
            case .invalidFormat: return "不是有效的备份数据"
            }
        }
    }

    struct Restored {
        var books: [Book]
        var progress: [UUID: ReadingProgress]
    }

    // MARK: - 文件结构

    private struct File: Codable {
        var app: String?
        var version: Int?
        var exportTime: String?
        var books: [BookEntry]
    }

    private struct BookEntry: Codable {
        var id: String?
        var title: String?
        var author: String?
        var desc: String?
        var chapters: [ChapterEntry]?
        var createTime: Double?
        var lastChapterIndex: Int?
        var lastReadTime: Double?
        var coverBase64: String?
        var bookmarks: [Bookmark]?
        var notes: [Note]?
    }

    private struct ChapterEntry: Codable {
        var id: String?
        var title: String?
        var content: String?
    }

    // MARK: - 导出

    static func encode(
        books: [Book],
        progress: [UUID: ReadingProgress],
        now: Date = Date()
    ) throws -> Data {
        let entries = books.map { book -> BookEntry in
            let saved = progress[book.id]
            return BookEntry(
                id: book.id.uuidString,
                title: book.title,
                author: book.author,
                desc: book.desc,
                chapters: book.chapters.map {
                    ChapterEntry(id: $0.id.uuidString, title: $0.title, content: $0.content)
                },
                createTime: book.createdAt.timeIntervalSince1970 * 1000,
                lastChapterIndex: saved?.chapterIndex ?? 0,
                lastReadTime: saved.map { $0.updatedAt.timeIntervalSince1970 * 1000 } ?? 0,
                coverBase64: book.coverData.map { dataURL(for: $0) },
                bookmarks: book.bookmarks.isEmpty ? nil : book.bookmarks,
                notes: book.notes.isEmpty ? nil : book.notes
            )
        }
        let file = File(
            app: "YueShu",
            version: 2,
            exportTime: ISO8601DateFormatter().string(from: now),
            books: entries
        )
        return try JSONEncoder().encode(file)
    }

    // MARK: - 导入

    static func decode(_ data: Data) throws -> Restored {
        guard let file = try? JSONDecoder().decode(File.self, from: data) else {
            throw BackupError.invalidFormat
        }
        var books: [Book] = []
        var progress: [UUID: ReadingProgress] = [:]

        for entry in file.books {
            let chapters = restoredChapters(from: entry.chapters)
            let chapterIDs = Set(chapters.map(\.id))
            let createdAt = entry.createTime.flatMap { $0 > 0 ? Date(timeIntervalSince1970: $0 / 1000) : nil }
                ?? Date()
            let book = Book(
                id: entry.id.flatMap { UUID(uuidString: $0) } ?? UUID(),
                title: entry.title ?? "未命名",
                author: entry.author ?? "佚名",
                desc: entry.desc ?? "",
                coverData: entry.coverBase64.flatMap(imageData(fromDataURL:)),
                chapters: chapters,
                createdAt: createdAt,
                bookmarks: (entry.bookmarks ?? []).filter { chapterIDs.contains($0.chapterID) },
                notes: (entry.notes ?? []).filter { chapterIDs.contains($0.chapterID) }
            )
            books.append(book)

            if let readTime = entry.lastReadTime, readTime > 0 {
                let index = min(max(entry.lastChapterIndex ?? 0, 0), chapters.count - 1)
                progress[book.id] = ReadingProgress(
                    chapterIndex: index,
                    paragraphIndex: 0,
                    updatedAt: Date(timeIntervalSince1970: readTime / 1000)
                )
            }
        }
        return Restored(books: books, progress: progress)
    }

    // MARK: - 辅助

    private static func restoredChapters(from entries: [ChapterEntry]?) -> [Chapter] {
        let restored = (entries ?? []).map {
            Chapter(
                id: $0.id.flatMap { UUID(uuidString: $0) } ?? UUID(),
                title: $0.title ?? "未命名章节",
                content: $0.content ?? ""
            )
        }
        return restored.isEmpty ? [Chapter(title: "第一章", content: "")] : restored
    }

    /// 把图片数据包成 `data:image/...;base64,...`,和网页版的封面格式一致。
    static func dataURL(for imageData: Data) -> String {
        let mime = imageData.starts(with: [0x89, 0x50]) ? "image/png" : "image/jpeg"
        return "data:\(mime);base64,\(imageData.base64EncodedString())"
    }

    /// 从 `data:image/...;base64,...` 取出图片数据;格式不对返回 nil。
    static func imageData(fromDataURL string: String) -> Data? {
        guard string.hasPrefix("data:"),
              let comma = string.firstIndex(of: ",") else { return nil }
        let payload = String(string[string.index(after: comma)...])
        return Data(base64Encoded: payload)
    }
}
