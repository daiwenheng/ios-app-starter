import Foundation

/// 某本书的阅读进度。
/// `paragraphIndex` 是阅读页内容块的序号:0 是章节标题,1 起是正文段落。
/// `updatedAt` 是最后阅读时间,书架按它排序。比较两个进度时只看读到哪里,不看时间。
struct ReadingProgress: Codable, Equatable, Sendable {
    var chapterIndex: Int
    var paragraphIndex: Int
    var updatedAt: Date

    init(chapterIndex: Int, paragraphIndex: Int, updatedAt: Date = Date()) {
        self.chapterIndex = chapterIndex
        self.paragraphIndex = paragraphIndex
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case chapterIndex, paragraphIndex, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        chapterIndex = try container.decode(Int.self, forKey: .chapterIndex)
        paragraphIndex = try container.decode(Int.self, forKey: .paragraphIndex)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
            ?? Date(timeIntervalSince1970: 0)
    }

    static func == (lhs: ReadingProgress, rhs: ReadingProgress) -> Bool {
        lhs.chapterIndex == rhs.chapterIndex && lhs.paragraphIndex == rhs.paragraphIndex
    }

    /// 把进度限制在这本书的章节范围内;章节数为 0 时返回 nil。
    /// 章节序号越界时回到最近的合法章节,并从该章开头读起。
    func clamped(chapterCount: Int) -> ReadingProgress? {
        guard chapterCount > 0 else { return nil }
        let lastIndex = chapterCount - 1
        guard (0...lastIndex).contains(chapterIndex) else {
            return ReadingProgress(
                chapterIndex: min(max(chapterIndex, 0), lastIndex),
                paragraphIndex: 0,
                updatedAt: updatedAt
            )
        }
        return ReadingProgress(
            chapterIndex: chapterIndex,
            paragraphIndex: max(paragraphIndex, 0),
            updatedAt: updatedAt
        )
    }

    /// 读到第几章占总章数的百分比((当前章 + 1) / 总章数),章节数为 0 时返回 nil。
    func percent(chapterCount: Int) -> Int? {
        guard let current = clamped(chapterCount: chapterCount) else { return nil }
        return Int((Double(current.chapterIndex + 1) / Double(chapterCount) * 100).rounded())
    }
}
