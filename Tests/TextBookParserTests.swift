import XCTest
@testable import NovelReader

final class TextBookParserTests: XCTestCase {
    private var gb18030: String.Encoding {
        let raw = CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
        )
        return String.Encoding(rawValue: raw)
    }

    // MARK: - 分章

    func testSplitsChaptersByHeadings() {
        let text = "第一章 开始\n内容甲\n\n第二章 继续\n内容乙\n第三回 收尾\n内容丙"
        let chapters = TextBookParser.splitChapters(text)
        XCTAssertEqual(chapters.map(\.title), ["第一章 开始", "第二章 继续", "第三回 收尾"])
        XCTAssertEqual(chapters.map(\.content), ["内容甲", "内容乙", "内容丙"])
    }

    func testTextBeforeFirstHeadingBecomesPreface() {
        let chapters = TextBookParser.splitChapters("这是简介\n第一章 起\n正文")
        XCTAssertEqual(chapters.map(\.title), ["前言", "第一章 起"])
        XCTAssertEqual(chapters[0].content, "这是简介")
    }

    func testHandlesWindowsLineEndings() {
        let chapters = TextBookParser.splitChapters("第一章 甲\r\n内容一\r\n第二章 乙\r\n内容二\r\n")
        XCTAssertEqual(chapters.map(\.title), ["第一章 甲", "第二章 乙"])
        XCTAssertEqual(chapters[1].content, "内容二")
    }

    func testRecognizesSpecialAndEnglishHeadings() {
        XCTAssertTrue(TextBookParser.isHeading("序章"))
        XCTAssertTrue(TextBookParser.isHeading("番外 小故事"))
        XCTAssertTrue(TextBookParser.isHeading("Chapter 12"))
        XCTAssertTrue(TextBookParser.isHeading("  第一百二十三章 很长的名字  "))
    }

    func testOrdinaryTextIsNotHeading() {
        XCTAssertFalse(TextBookParser.isHeading("第一次见面的时候,他们谁也没有说话。"))
        XCTAssertFalse(TextBookParser.isHeading("他说第一章已经读完了"))
        XCTAssertFalse(TextBookParser.isHeading(""))
    }

    func testVeryLongLineStartingWithHeadingIsNotHeading() {
        let line = "第一章" + String(repeating: "很", count: 60)
        XCTAssertFalse(TextBookParser.isHeading(line))
    }

    func testShortTextWithoutHeadingsIsOneChapter() {
        let chapters = TextBookParser.splitChapters("只有一段话。\n\n还有另一段。")
        XCTAssertEqual(chapters.count, 1)
        XCTAssertEqual(chapters[0].title, "正文")
        XCTAssertEqual(chapters[0].content, "只有一段话。\n还有另一段。")
    }

    func testLongTextWithoutHeadingsIsChunked() {
        let paragraph = String(repeating: "字", count: 100)
        let text = Array(repeating: paragraph, count: 100).joined(separator: "\n")
        let chapters = TextBookParser.splitChapters(text)
        XCTAssertGreaterThan(chapters.count, 1)
        XCTAssertEqual(chapters.first?.title, "第 1 部分")
        let totalCharacters = chapters
            .map { chapter in chapter.content.filter { character in character != "\n" }.count }
            .reduce(0, +)
        XCTAssertEqual(totalCharacters, 10_000)
    }

    func testBlankTextHasNoChapters() {
        XCTAssertTrue(TextBookParser.splitChapters("").isEmpty)
        XCTAssertTrue(TextBookParser.splitChapters("  \n\u{3000}\n\r\n").isEmpty)
    }

    // MARK: - 生成书

    func testBookTitleComesFromFileName() throws {
        let book = try TextBookParser.makeBook(from: Data("第一章 甲\n内容".utf8), fileName: "我的小说.txt")
        XCTAssertEqual(book.title, "我的小说")
        XCTAssertEqual(book.chapters.count, 1)
    }

    func testEmptyFileThrows() {
        XCTAssertThrowsError(try TextBookParser.makeBook(from: Data(), fileName: "空.txt")) { error in
            XCTAssertEqual(error as? TextBookParser.ImportError, .empty)
        }
    }

    func testUndecodableFileThrows() {
        // 单独的 0xFF 不是合法的 UTF-8;GB18030 也无法解码。
        let data = Data([0xFF, 0xFF, 0xFF])
        XCTAssertThrowsError(try TextBookParser.makeBook(from: data, fileName: "坏.txt")) { error in
            XCTAssertEqual(error as? TextBookParser.ImportError, .undecodable)
        }
    }

    // MARK: - 编码

    func testDecodesUTF8() {
        XCTAssertEqual(TextBookParser.decode(Data("你好,世界".utf8)), "你好,世界")
    }

    func testDecodesUTF8WithBOM() {
        let data = Data([0xEF, 0xBB, 0xBF]) + Data("你好".utf8)
        XCTAssertEqual(TextBookParser.decode(data), "你好")
    }

    func testDecodesUTF16WithBOM() throws {
        let data = try XCTUnwrap("你好".data(using: .utf16))
        XCTAssertEqual(TextBookParser.decode(data), "你好")
    }

    func testDecodesGB18030() throws {
        let data = try XCTUnwrap("你好,世界。第一章".data(using: gb18030))
        XCTAssertNil(String(data: data, encoding: .utf8), "测试数据必须不是合法 UTF-8")
        XCTAssertEqual(TextBookParser.decode(data), "你好,世界。第一章")
    }
}
