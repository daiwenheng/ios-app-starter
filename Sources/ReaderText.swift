import Foundation

/// 阅读页里的一个内容块:章节标题或一个正文段落。
struct ReaderBlock: Identifiable, Equatable, Sendable {
    /// 0 是标题,1 起是正文段落;同时也是阅读进度里的 `paragraphIndex`。
    let id: Int
    let text: String
    let isTitle: Bool
}

enum ReaderText {
    /// 按换行切段,去掉首尾空白(含全角空格)和空行。
    static func paragraphs(from content: String) -> [String] {
        content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    static func blocks(title: String, content: String) -> [ReaderBlock] {
        var result = [ReaderBlock(id: 0, text: title, isTitle: true)]
        for (offset, paragraph) in paragraphs(from: content).enumerated() {
            result.append(ReaderBlock(id: offset + 1, text: paragraph, isTitle: false))
        }
        return result
    }
}
