import Foundation
import Observation

/// 书架:保存所有书和每本书的阅读进度。
/// 书存成 Application Support 里的一个 JSON 文件;阅读进度存在 UserDefaults。
@MainActor
@Observable
final class LibraryStore {
    private(set) var books: [Book]
    private(set) var progress: [UUID: ReadingProgress]

    @ObservationIgnored private let fileURL: URL?
    @ObservationIgnored private let defaults: UserDefaults

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

    func remove(at offsets: IndexSet) {
        let ids = offsets.compactMap { books.indices.contains($0) ? books[$0].id : nil }
        remove(ids: ids)
    }

    func remove(ids: [UUID]) {
        guard !ids.isEmpty else { return }
        let removed = Set(ids)
        books.removeAll { removed.contains($0.id) }
        for id in removed { progress[id] = nil }
        saveBooks()
        saveProgress()
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
