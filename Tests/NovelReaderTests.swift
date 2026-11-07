import XCTest
@testable import NovelReader

final class NovelReaderTests: XCTestCase {
    func testBookHasChapters() {
        let book = Book(
            title: "测试书",
            author: "测试作者",
            chapters: [
                Chapter(title: "章节一", content: "内容")
            ]
        )
        XCTAssertFalse(book.chapters.isEmpty)
        XCTAssertEqual(book.title, "测试书")
    }
}
