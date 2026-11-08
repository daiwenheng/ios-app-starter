import Foundation

/// 某本书的阅读进度。
/// `paragraphIndex` 是阅读页内容块的序号:0 是章节标题,1 起是正文段落。
struct ReadingProgress: Codable, Equatable, Sendable {
    var chapterIndex: Int
    var paragraphIndex: Int

    /// 把进度限制在这本书的章节范围内;章节数为 0 时返回 nil。
    /// 章节序号越界时回到最近的合法章节,并从该章开头读起。
    func clamped(chapterCount: Int) -> ReadingProgress? {
        guard chapterCount > 0 else { return nil }
        let lastIndex = chapterCount - 1
        guard (0...lastIndex).contains(chapterIndex) else {
            return ReadingProgress(chapterIndex: min(max(chapterIndex, 0), lastIndex), paragraphIndex: 0)
        }
        return ReadingProgress(chapterIndex: chapterIndex, paragraphIndex: max(paragraphIndex, 0))
    }
}

/// 从目录或书架进入阅读页的导航目标。
struct ReaderRoute: Hashable {
    let bookID: UUID
    let chapterIndex: Int
    let paragraphIndex: Int
}
