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

    // MARK: - 阅读设置

    func testSettingsAreClampedIntoRanges() {
        var settings = ReaderSettings()
        settings.fontSize = 1
        settings.lineHeight = 99
        settings.letterSpacing = -50
        settings.paraGap = 99
        settings.padX = -3
        settings.padY = 500
        let clamped = settings.clamped()
        XCTAssertEqual(clamped.fontSize, ReaderSettings.fontSizeRange.lowerBound)
        XCTAssertEqual(clamped.lineHeight, ReaderSettings.lineHeightRange.upperBound)
        XCTAssertEqual(clamped.letterSpacing, ReaderSettings.letterSpacingRange.lowerBound)
        XCTAssertEqual(clamped.paraGap, ReaderSettings.paraGapRange.upperBound)
        XCTAssertEqual(clamped.padX, ReaderSettings.padXRange.lowerBound)
        XCTAssertEqual(clamped.padY, ReaderSettings.padYRange.upperBound)
    }

    func testDefaultsAreInsideRanges() {
        let d = ReaderSettings()
        XCTAssertTrue(ReaderSettings.fontSizeRange.contains(d.fontSize))
        XCTAssertTrue(ReaderSettings.lineHeightRange.contains(d.lineHeight))
        XCTAssertTrue(ReaderSettings.letterSpacingRange.contains(d.letterSpacing))
        XCTAssertTrue(ReaderSettings.paraGapRange.contains(d.paraGap))
        XCTAssertTrue(ReaderSettings.padXRange.contains(d.padX))
        XCTAssertTrue(ReaderSettings.padYRange.contains(d.padY))
        XCTAssertEqual(d.theme, .system)
    }

    func testThemesHaveUniqueIdsAndNames() {
        let themes = ReaderThemeKind.allCases
        XCTAssertEqual(Set(themes.map(\.id)).count, themes.count)
        XCTAssertEqual(Set(themes.map(\.displayName)).count, themes.count)
    }

    func testSettingsDecodeFillsMissingFieldsAndClamps() throws {
        let json = #"{"fontSize": 500, "theme": "不存在"}"#
        let decoded = try JSONDecoder().decode(ReaderSettings.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.fontSize, ReaderSettings.fontSizeRange.upperBound)
        XCTAssertEqual(decoded.theme, .system)
        XCTAssertEqual(decoded.lineHeight, ReaderSettings().lineHeight)
    }

    @MainActor
    func testSettingsStorePersistsChanges() {
        let suite = "NovelReaderTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let store = ReaderSettingsStore(defaults: defaults)
        store.update { $0.fontSize = 22; $0.theme = .night }
        let reloaded = ReaderSettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.settings.fontSize, 22)
        XCTAssertEqual(reloaded.settings.theme, .night)
        reloaded.reset()
        XCTAssertEqual(ReaderSettingsStore(defaults: defaults).settings, ReaderSettings())
    }

    func testReaderPaletteFollowsSystemWhenThemeIsSystem() {
        XCTAssertFalse(ReaderPalette.resolve(.system, systemIsDark: false).isDark)
        XCTAssertTrue(ReaderPalette.resolve(.system, systemIsDark: true).isDark)
        XCTAssertTrue(ReaderPalette.resolve(.night, systemIsDark: false).isDark)
        XCTAssertFalse(ReaderPalette.resolve(.eyeCare, systemIsDark: true).isDark)
    }
}
