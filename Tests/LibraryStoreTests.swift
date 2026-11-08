import XCTest
@testable import NovelReader

@MainActor
final class LibraryStoreTests: XCTestCase {
    private struct Sandbox {
        let fileURL: URL
        let defaults: UserDefaults
    }

    private func makeSandbox() -> Sandbox {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "NovelReaderTests-\(UUID().uuidString)")
        let suite = "NovelReaderTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
            UserDefaults.standard.removePersistentDomain(forName: suite)
        }
        return Sandbox(fileURL: directory.appending(path: "library.json"), defaults: defaults)
    }

    private func makeBook(_ title: String) -> Book {
        Book(title: title, author: "作者", chapters: [Chapter(title: "第一章", content: "内容")])
    }

    func testFirstLaunchSeedsSampleBooksAndWritesFile() {
        let box = makeSandbox()
        let store = LibraryStore(fileURL: box.fileURL, defaults: box.defaults)
        XCTAssertEqual(store.books.map(\.title), SampleBooks.all.map(\.title))
        XCTAssertTrue(FileManager.default.fileExists(atPath: box.fileURL.path))
    }

    func testAddedBookIsFirstAndSurvivesReload() throws {
        let box = makeSandbox()
        let store = LibraryStore(fileURL: box.fileURL, defaults: box.defaults)
        let book = makeBook("新书")
        store.add(book)
        XCTAssertEqual(store.books.first?.id, book.id)

        let reloaded = LibraryStore(fileURL: box.fileURL, defaults: box.defaults)
        let found = try XCTUnwrap(reloaded.book(id: book.id))
        XCTAssertEqual(found.title, "新书")
        XCTAssertEqual(found.chapters.first?.content, "内容")
        XCTAssertEqual(reloaded.books.count, SampleBooks.all.count + 1)
    }

    func testDeletingEveryBookDoesNotBringSamplesBack() {
        let box = makeSandbox()
        let store = LibraryStore(fileURL: box.fileURL, defaults: box.defaults)
        store.remove(at: IndexSet(integersIn: 0..<store.books.count))
        XCTAssertTrue(store.books.isEmpty)

        let reloaded = LibraryStore(fileURL: box.fileURL, defaults: box.defaults)
        XCTAssertTrue(reloaded.books.isEmpty)
    }

    func testRemoveIgnoresOutOfRangeOffsets() {
        let box = makeSandbox()
        let store = LibraryStore(fileURL: box.fileURL, defaults: box.defaults)
        let before = store.books.count
        store.remove(at: IndexSet(integer: 99))
        XCTAssertEqual(store.books.count, before)
    }

    func testProgressPersistsAcrossReload() {
        let box = makeSandbox()
        let store = LibraryStore(fileURL: box.fileURL, defaults: box.defaults)
        let book = makeBook("进度")
        store.add(book)
        store.saveProgress(ReadingProgress(chapterIndex: 0, paragraphIndex: 7), for: book.id)

        let reloaded = LibraryStore(fileURL: box.fileURL, defaults: box.defaults)
        XCTAssertEqual(reloaded.progress(for: book.id), ReadingProgress(chapterIndex: 0, paragraphIndex: 7))
    }

    func testRemovingBookClearsItsProgress() {
        let box = makeSandbox()
        let store = LibraryStore(fileURL: box.fileURL, defaults: box.defaults)
        let book = makeBook("会被删除")
        store.add(book)
        store.saveProgress(ReadingProgress(chapterIndex: 0, paragraphIndex: 3), for: book.id)

        store.remove(ids: [book.id])
        XCTAssertNil(store.book(id: book.id))
        XCTAssertNil(store.progress(for: book.id))

        let reloaded = LibraryStore(fileURL: box.fileURL, defaults: box.defaults)
        XCTAssertNil(reloaded.progress(for: book.id))
    }

    func testCorruptLibraryFileFallsBackToSamplesAndKeepsBackup() throws {
        let box = makeSandbox()
        try FileManager.default.createDirectory(
            at: box.fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("这不是 JSON".utf8).write(to: box.fileURL)

        let store = LibraryStore(fileURL: box.fileURL, defaults: box.defaults)
        XCTAssertEqual(store.books.map(\.title), SampleBooks.all.map(\.title))

        let backup = box.fileURL.deletingPathExtension().appendingPathExtension("corrupt.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: backup.path))
    }

    func testStoreWithoutFileURLStaysInMemory() {
        let box = makeSandbox()
        let store = LibraryStore(fileURL: nil, defaults: box.defaults)
        store.add(makeBook("内存书"))
        XCTAssertEqual(store.books.first?.title, "内存书")
        XCTAssertFalse(FileManager.default.fileExists(atPath: box.fileURL.path))
    }

    func testSampleBooksHaveContent() {
        for book in SampleBooks.all {
            XCTAssertFalse(book.chapters.isEmpty, book.title)
            for chapter in book.chapters {
                XCTAssertFalse(ReaderText.paragraphs(from: chapter.content).isEmpty, chapter.title)
            }
        }
    }
}
