import Foundation
import Observation
import UIKit

/// 书架:保存所有书和每本书的阅读进度。
/// 书存成 Application Support 里的一个 JSON 文件;阅读进度存在 UserDefaults。
@MainActor
@Observable
final class LibraryStore {
    private(set) var books: [Book]
    private(set) var progress: [UUID: ReadingProgress]

    @ObservationIgnored private let fileURL: URL?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var coverCache: [UUID: (size: Int, image: UIImage)] = [:]

    static let progressDefaultsKey = "library.progress.v1"

    nonisolated static var defaultFileURL: URL {
        URL.applicationSupportDirectory.appending(path: "NovelReader/library.json")
    }

    /// - Parameters:
    ///   - fileURL: 书架文件位置;传 nil 表示只放在内存里(预览和测试用)。
    ///   - defaults: 保存阅读进度的 UserDefaults。
    init(fileURL: URL? = LibraryStore.defaultFileURL, defaults: UserDefaults = .standard) {
        self.fileURL = fileURL
        self.defaults = defaults
        self.progress = Self.loadProgress(from: defaults)

        var shouldSave = false
        if let fileURL, let data = try? Data(contentsOf: fileURL) {
            if let decoded = try? JSONDecoder().decode([Book].self, from: data) {
                self.books = decoded
            } else {
                // 文件损坏:把它挪到一边留作备份,重新从示例书开始。
                let backup = fileURL.deletingPathExtension().appendingPathExtension("corrupt.json")
                try? FileManager.default.removeItem(at: backup)
                try? FileManager.default.moveItem(at: fileURL, to: backup)
                self.books = SampleBooks.all
                shouldSave = true
            }
        } else {
            // 第一次启动(还没有书架文件)。
            self.books = SampleBooks.all
            shouldSave = true
        }
        if shouldSave { saveBooks() }
    }

    // MARK: - 书

    func book(id: UUID) -> Book? {
        books.first { $0.id == id }
    }

    /// 新书放在最前面。
    func add(_ book: Book) {
        books.insert(book, at: 0)
        saveBooks()
    }

    /// 修改一本书(改信息、改正文、改目录、加书签……),改完立刻保存。
    func update(bookID: UUID, _ change: (inout Book) -> Void) {
        guard let index = books.firstIndex(where: { $0.id == bookID }) else { return }
        change(&books[index])
        saveBooks()
    }

    func remove(at offsets: IndexSet) {
        let ids = offsets.compactMap { books.indices.contains($0) ? books[$0].id : nil }
        remove(ids: ids)
    }

    func remove(ids: [UUID]) {
        guard !ids.isEmpty else { return }
        let removed = Set(ids)
        books.removeAll { removed.contains($0.id) }
        for id in removed {
            progress[id] = nil
            coverCache[id] = nil
        }
        saveBooks()
        saveProgress()
    }

    /// 从备份恢复:覆盖当前所有书和阅读进度。
    func replaceAll(books newBooks: [Book], progress newProgress: [UUID: ReadingProgress]) {
        books = newBooks
        progress = newProgress
        coverCache = [:]
        saveBooks()
        saveProgress()
    }

    /// 书架显示顺序:最近读过的在前,没读过的按添加时间从新到旧。
    /// `query` 不为空时,只留下书名或作者包含它的书。
    func sortedBooks(matching query: String = "") -> [Book] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = trimmed.isEmpty
            ? books
            : books.filter {
                $0.title.localizedCaseInsensitiveContains(trimmed)
                    || $0.author.localizedCaseInsensitiveContains(trimmed)
            }
        return filtered.sorted { lhs, rhs in
            let left = progress[lhs.id]?.updatedAt ?? .distantPast
            let right = progress[rhs.id]?.updatedAt ?? .distantPast
            if left != right { return left > right }
            return lhs.createdAt > rhs.createdAt
        }
    }

    /// 最近读过的一本书(没读过任何书时为 nil)。
    var mostRecentlyRead: Book? {
        books
            .filter { progress[$0.id] != nil }
            .max { (progress[$0.id]?.updatedAt ?? .distantPast) < (progress[$1.id]?.updatedAt ?? .distantPast) }
    }

    // MARK: - 封面

    func coverImage(for book: Book) -> UIImage? {
        guard let data = book.coverData else {
            coverCache[book.id] = nil
            return nil
        }
        if let cached = coverCache[book.id], cached.size == data.count {
            return cached.image
        }
        guard let image = UIImage(data: data) else { return nil }
        coverCache[book.id] = (data.count, image)
        return image
    }

    // MARK: - 阅读进度

    func progress(for bookID: UUID) -> ReadingProgress? {
        progress[bookID]
    }

    func saveProgress(_ value: ReadingProgress, for bookID: UUID) {
        guard progress[bookID] != value else { return }
        progress[bookID] = value
        saveProgress()
    }

    /// 打开一本书时记一下"刚读过",书架据此把它排到最前面。
    func markOpened(_ bookID: UUID, at date: Date = Date()) {
        guard books.contains(where: { $0.id == bookID }) else { return }
        var current = progress[bookID] ?? ReadingProgress(chapterIndex: 0, paragraphIndex: 0)
        current.updatedAt = date
        progress[bookID] = current
        saveProgress()
    }

    // MARK: - 持久化

    private func saveBooks() {
        guard let fileURL else { return }
        guard let data = try? JSONEncoder().encode(books) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
    }

    private func saveProgress() {
        let stored = Dictionary(uniqueKeysWithValues: progress.map { ($0.key.uuidString, $0.value) })
        guard let data = try? JSONEncoder().encode(stored) else { return }
        defaults.set(data, forKey: Self.progressDefaultsKey)
    }

    private static func loadProgress(from defaults: UserDefaults) -> [UUID: ReadingProgress] {
        guard
            let data = defaults.data(forKey: progressDefaultsKey),
            let stored = try? JSONDecoder().decode([String: ReadingProgress].self, from: data)
        else { return [:] }
        var result: [UUID: ReadingProgress] = [:]
        for (key, value) in stored {
            if let id = UUID(uuidString: key) { result[id] = value }
        }
        return result
    }
}
