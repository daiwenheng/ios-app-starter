import XCTest
@testable import NovelReader

final class ReaderTests: XCTestCase {
    // MARK: - 内容块

    func testBlocksStartWithTitleThenParagraphs() {
        let blocks = ReaderText.blocks(title: "第一章", content: "甲\n\n  乙  \n\u{3000}丙\n")
        XCTAssertEqual(blocks.map(\.id), [0, 1, 2, 3])
        XCTAssertEqual(blocks.map(\.text), ["第一章", "甲", "乙", "丙"])
        XCTAssertEqual(blocks.map(\.isTitle), [true, false, false, false])
    }

    func testBlocksOfEmptyContentOnlyHaveTitle() {
        let blocks = ReaderText.blocks(title: "空章", content: "\n \n")
        XCTAssertEqual(blocks.count, 1)
        XCTAssertTrue(blocks[0].isTitle)
    }

    // MARK: - 阅读进度

    func testProgressInRangeIsKept() {
        let progress = ReadingProgress(chapterIndex: 2, paragraphIndex: 5)
        XCTAssertEqual(progress.clamped(chapterCount: 3), progress)
    }

    func testProgressBeyondLastChapterGoesToLastChapterStart() {
        let progress = ReadingProgress(chapterIndex: 9, paragraphIndex: 5)
        XCTAssertEqual(progress.clamped(chapterCount: 3), ReadingProgress(chapterIndex: 2, paragraphIndex: 0))
    }

    func testNegativeProgressIsClamped() {
        XCTAssertEqual(
            ReadingProgress(chapterIndex: -1, paragraphIndex: 4).clamped(chapterCount: 3),
            ReadingProgress(chapterIndex: 0, paragraphIndex: 0)
        )
        XCTAssertEqual(
            ReadingProgress(chapterIndex: 1, paragraphIndex: -4).clamped(chapterCount: 3),
            ReadingProgress(chapterIndex: 1, paragraphIndex: 0)
        )
    }

    func testProgressOfBookWithoutChaptersIsNil() {
        XCTAssertNil(ReadingProgress(chapterIndex: 0, paragraphIndex: 0).clamped(chapterCount: 0))
    }

    // MARK: - 阅读样式

    func testFontSizeAndLineSpacingAreClamped() {
        XCTAssertEqual(ReaderStyle.clampedFontSize(1), ReaderStyle.fontSizeRange.lowerBound)
        XCTAssertEqual(ReaderStyle.clampedFontSize(999), ReaderStyle.fontSizeRange.upperBound)
        XCTAssertEqual(ReaderStyle.clampedFontSize(20), 20)
        XCTAssertEqual(ReaderStyle.clampedLineSpacing(-5), ReaderStyle.lineSpacingRange.lowerBound)
        XCTAssertEqual(ReaderStyle.clampedLineSpacing(100), ReaderStyle.lineSpacingRange.upperBound)
    }

    func testDefaultsAreInsideRanges() {
        XCTAssertTrue(ReaderStyle.fontSizeRange.contains(ReaderStyle.defaultFontSize))
        XCTAssertTrue(ReaderStyle.lineSpacingRange.contains(ReaderStyle.defaultLineSpacing))
    }

    func testThemesHaveUniqueIdsAndNames() {
        let themes = ReaderTheme.allCases
        XCTAssertEqual(Set(themes.map(\.id)).count, themes.count)
        XCTAssertEqual(Set(themes.map(\.displayName)).count, themes.count)
    }

    func testThemeColorSchemes() {
        XCTAssertNil(ReaderTheme.system.colorScheme)
        XCTAssertEqual(ReaderTheme.light.colorScheme, .light)
        XCTAssertEqual(ReaderTheme.sepia.colorScheme, .light)
        XCTAssertEqual(ReaderTheme.dark.colorScheme, .dark)
    }

    func testUnknownStoredThemeFallsBackToSystem() {
        XCTAssertEqual(ReaderTheme(rawValue: "不存在") ?? .system, .system)
        XCTAssertEqual(ReaderTheme(rawValue: ReaderTheme.dark.rawValue), .dark)
    }
}
