import XCTest
@testable import NovelReader

final class FeatureTests: XCTestCase {
    private func sampleBook() -> Book {
        Book(title: "书", author: "我", chapters: [
            Chapter(title: "一", content: "甲"),
            Chapter(title: "二", content: "乙"),
            Chapter(title: "三", content: "丙"),
        ])
    }

    // MARK: - 目录编辑

    func testAppendAndInsertChapter() {
        var book = sampleBook()
        XCTAssertEqual(book.appendChapter(title: "末"), 3)
        XCTAssertEqual(book.insertChapter(title: "插", after: 0), 1)
        XCTAssertEqual(book.chapters.map(\.title), ["一", "插", "二", "三", "末"])
    }

    func testMoveChapter() {
        var book = sampleBook()
        XCTAssertEqual(book.moveChapter(at: 0, by: 1), 1)
        XCTAssertEqual(book.chapters.map(\.title), ["二", "一", "三"])
        XCTAssertNil(book.moveChapter(at: 0, by: -1))
        XCTAssertNil(book.moveChapter(at: 2, by: 1))
    }

    func testRenameChapter() {
        var book = sampleBook()
        book.renameChapter(at: 1, to: "新")
        XCTAssertEqual(book.chapters[1].title, "新")
        book.renameChapter(at: 9, to: "无效")
        XCTAssertEqual(book.chapters.count, 3)
    }

    func testDeleteChapterRemovesItsBookmarksAndNotesAndKeepsLastChapter() {
        var book = sampleBook()
        book.addBookmark(chapterIndex: 1, blockIndex: 1, excerpt: "乙")
        book.addNote(chapterIndex: 1, blockIndex: 1, quote: "乙", text: "想法")
        book.addBookmark(chapterIndex: 0, blockIndex: 1, excerpt: "甲")
        XCTAssertTrue(book.deleteChapter(at: 1))
        XCTAssertEqual(book.bookmarks.count, 1)
        XCTAssertTrue(book.notes.isEmpty)
        XCTAssertTrue(book.deleteChapter(at: 1))
        XCTAssertFalse(book.deleteChapter(at: 0), "至少保留一章")
        XCTAssertEqual(book.chapters.count, 1)
    }

    func testChapterIndexMath() {
        XCTAssertEqual(ChapterIndexMath.afterMove(current: 1, from: 1, to: 2), 2)
        XCTAssertEqual(ChapterIndexMath.afterMove(current: 2, from: 1, to: 2), 1)
        XCTAssertEqual(ChapterIndexMath.afterMove(current: 1, from: 2, to: 1), 2)
        XCTAssertEqual(ChapterIndexMath.afterMove(current: 0, from: 1, to: 2), 0)
        XCTAssertEqual(ChapterIndexMath.afterDelete(current: 2, deleted: 0, newCount: 2), 1)
        XCTAssertEqual(ChapterIndexMath.afterDelete(current: 2, deleted: 2, newCount: 2), 1)
        XCTAssertEqual(ChapterIndexMath.afterDelete(current: 0, deleted: 1, newCount: 2), 0)
    }

    // MARK: - 书签与笔记

    func testBookmarkIsNotDuplicated() {
        var book = sampleBook()
        XCTAssertTrue(book.addBookmark(chapterIndex: 0, blockIndex: 2, excerpt: "x"))
        XCTAssertFalse(book.addBookmark(chapterIndex: 0, blockIndex: 2, excerpt: "x"))
        XCTAssertFalse(book.addBookmark(chapterIndex: 9, blockIndex: 0, excerpt: "x"))
        XCTAssertEqual(book.bookmarks.count, 1)
    }

    func testEmptyNoteIsRejectedAndTextIsTrimmed() {
        var book = sampleBook()
        XCTAssertFalse(book.addNote(chapterIndex: 0, blockIndex: 0, quote: "", text: "  \n"))
        XCTAssertTrue(book.addNote(chapterIndex: 0, blockIndex: 0, quote: "", text: " 好 "))
        XCTAssertEqual(book.notes.first?.text, "好")
    }

    // MARK: - 旧数据兼容

    func testOldLibraryJSONStillDecodes() throws {
        let id = UUID()
        let json = """
        [{"id":"\(id.uuidString)","title":"旧书","author":"甲",
          "chapters":[{"id":"\(UUID().uuidString)","title":"一","content":"x"}]}]
        """
        let books = try JSONDecoder().decode([Book].self, from: Data(json.utf8))
        XCTAssertEqual(books.first?.id, id)
        XCTAssertEqual(books.first?.desc, "")
        XCTAssertNil(books.first?.coverData)
        XCTAssertTrue(books.first?.bookmarks.isEmpty ?? false)
    }

    // MARK: - 对话染色

    func testDialogueSegments() {
        let segments = DialogueHighlighter.segments(in: "她说“你好”,然后走了。")
        XCTAssertEqual(segments.map(\.text), ["她说", "“你好”", ",然后走了。"])
        XCTAssertEqual(segments.map(\.isDialogue), [false, true, false])
    }

    func testCornerBracketDialogueAndUnpairedQuote() {
        XCTAssertEqual(DialogueHighlighter.segments(in: "「好」").map(\.isDialogue), [true])
        XCTAssertEqual(DialogueHighlighter.segments(in: "只有“开头").map(\.isDialogue), [false])
        XCTAssertEqual(DialogueHighlighter.segments(in: "“”").map(\.isDialogue), [false])
    }

    // MARK: - 书籍表单

    func testDraftDefaultsAndValidation() {
        var draft = BookDraft(title: "  ", chapters: [Chapter(title: "一", content: "")])
        XCTAssertFalse(draft.canSave)
        XCTAssertNil(draft.makeBook())
        draft.title = " 书名 "
        let book = draft.makeBook()
        XCTAssertEqual(book?.title, "书名")
        XCTAssertEqual(book?.author, BookDraft.defaultAuthor)
        XCTAssertEqual(book?.desc, BookDraft.defaultDesc)
    }

    func testDraftApplyKeepsChaptersAndAnnotations() {
        var book = sampleBook()
        book.addBookmark(chapterIndex: 0, blockIndex: 1, excerpt: "x")
        var draft = BookDraft(editing: book)
        draft.title = "改名"
        draft.apply(to: &book)
        XCTAssertEqual(book.title, "改名")
        XCTAssertEqual(book.chapters.count, 3)
        XCTAssertEqual(book.bookmarks.count, 1)
    }

    // MARK: - 备份

    func testBackupRoundTripKeepsEverything() throws {
        var book = sampleBook()
        book.desc = "简介"
        book.coverData = Data([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3])
        book.addBookmark(chapterIndex: 1, blockIndex: 1, excerpt: "乙")
        book.addNote(chapterIndex: 2, blockIndex: 0, quote: "三", text: "笔记")
        let progress = [book.id: ReadingProgress(chapterIndex: 2, paragraphIndex: 0, updatedAt: Date(timeIntervalSince1970: 1_700_000_000))]

        let data = try BackupCodec.encode(books: [book], progress: progress)
        let restored = try BackupCodec.decode(data)
        let back = try XCTUnwrap(restored.books.first)
        XCTAssertEqual(back.id, book.id)
        XCTAssertEqual(back.desc, "简介")
        XCTAssertEqual(back.coverData, book.coverData)
        XCTAssertEqual(back.chapters.map(\.title), ["一", "二", "三"])
        XCTAssertEqual(back.chapters.map(\.id), book.chapters.map(\.id))
        XCTAssertEqual(back.bookmarks.count, 1)
        XCTAssertEqual(back.notes.first?.text, "笔记")
        XCTAssertEqual(restored.progress[book.id]?.chapterIndex, 2)
    }

    func testImportsBackupFromHTMLVersion() throws {
        let json = """
        {"app":"YueShu","version":2,"exportTime":"2026-01-01T00:00:00.000Z","books":[
          {"id":"1712345678901","title":"网页版的书","author":"某人","desc":"简介",
           "chapters":[{"title":"第一章","content":"你好"},{"title":"第二章","content":"再见"}],
           "createTime":1712345678901,"lastChapterIndex":1,"lastReadTime":1712345999000,
           "coverBase64":"data:image/jpeg;base64,/9j/4AAQ"}]}
        """
        let restored = try BackupCodec.decode(Data(json.utf8))
        let book = try XCTUnwrap(restored.books.first)
        XCTAssertEqual(book.title, "网页版的书")
        XCTAssertEqual(book.chapters.count, 2)
        XCTAssertNotNil(book.coverData)
        XCTAssertEqual(restored.progress[book.id]?.chapterIndex, 1)
    }

    func testBackupFillsMissingFieldsAndRejectsGarbage() throws {
        let restored = try BackupCodec.decode(Data(#"{"books":[{}]}"#.utf8))
        XCTAssertEqual(restored.books.first?.title, "未命名")
        XCTAssertEqual(restored.books.first?.chapters.count, 1)
        XCTAssertThrowsError(try BackupCodec.decode(Data("不是 JSON".utf8)))
        XCTAssertThrowsError(try BackupCodec.decode(Data(#"{"x":1}"#.utf8)))
    }

    func testDataURLRoundTrip() {
        let png = Data([0x89, 0x50, 0x4E, 0x47, 9])
        let url = BackupCodec.dataURL(for: png)
        XCTAssertTrue(url.hasPrefix("data:image/png;base64,"))
        XCTAssertEqual(BackupCodec.imageData(fromDataURL: url), png)
        XCTAssertNil(BackupCodec.imageData(fromDataURL: "http://x"))
    }

    // MARK: - 封面

    func testCoverGlyphAndHue() {
        XCTAssertEqual(coverGlyph(for: "《雪夜来信》"), "雪")
        XCTAssertEqual(coverGlyph(for: "  "), "书")
        let id = UUID()
        XCTAssertEqual(CoverHue.index(for: id), CoverHue.index(for: id))
        XCTAssertTrue((0..<CoverHue.colors.count).contains(CoverHue.index(for: id)))
    }
}

@MainActor
final class LibraryStoreFeatureTests: XCTestCase {
    private func makeStore() -> LibraryStore {
        let suite = "NovelReaderTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: suite) }
        return LibraryStore(fileURL: nil, defaults: defaults)
    }

    func testUpdateChangesOneBook() throws {
        let store = makeStore()
        let id = try XCTUnwrap(store.books.first?.id)
        store.update(bookID: id) { $0.title = "改过" }
        XCTAssertEqual(store.book(id: id)?.title, "改过")
    }

    func testSortedBooksPutsRecentlyOpenedFirstAndFilters() throws {
        let store = makeStore()
        let last = try XCTUnwrap(store.books.last)
        XCTAssertNil(store.mostRecentlyRead)
        store.markOpened(last.id)
        XCTAssertEqual(store.sortedBooks().first?.id, last.id)
        XCTAssertEqual(store.mostRecentlyRead?.id, last.id)
        XCTAssertEqual(store.sortedBooks(matching: last.title).map(\.id), [last.id])
        XCTAssertTrue(store.sortedBooks(matching: "不存在的书名xyz").isEmpty)
    }

    func testReplaceAllOverwritesBooksAndProgress() {
        let store = makeStore()
        let book = Book(title: "新", author: "我", chapters: [Chapter(title: "一", content: "")])
        store.replaceAll(books: [book], progress: [book.id: ReadingProgress(chapterIndex: 0, paragraphIndex: 3)])
        XCTAssertEqual(store.books.map(\.id), [book.id])
        XCTAssertEqual(store.progress(for: book.id)?.paragraphIndex, 3)
    }
}
