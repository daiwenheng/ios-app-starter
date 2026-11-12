import Foundation

/// 一段文字被切成"普通文字"和"对话"两种片段,阅读页给对话单独染色。
struct TextSegment: Equatable, Sendable {
    let text: String
    let isDialogue: Bool
}

enum DialogueHighlighter {
    private static let pairs: [Character: Character] = ["“": "”", "「": "」"]

    /// 把 “……” 和 「……」 包住的内容(含引号)标成对话。
    /// 引号里至少要有一个字;没有配对的引号当作普通文字。
    static func segments(in text: String) -> [TextSegment] {
        let characters = Array(text)
        var result: [TextSegment] = []
        var normal = ""
        var index = 0

        func flushNormal() {
            if !normal.isEmpty {
                result.append(TextSegment(text: normal, isDialogue: false))
                normal = ""
            }
        }

        while index < characters.count {
            let character = characters[index]
            if let closer = pairs[character],
               let end = closingIndex(of: closer, in: characters, after: index),
               end > index + 1 {
                flushNormal()
                result.append(TextSegment(text: String(characters[index...end]), isDialogue: true))
                index = end + 1
            } else {
                normal.append(character)
                index += 1
            }
        }
        flushNormal()
        return result
    }

    private static func closingIndex(of closer: Character, in characters: [Character], after start: Int) -> Int? {
        var cursor = start + 1
        while cursor < characters.count {
            if characters[cursor] == closer { return cursor }
            cursor += 1
        }
        return nil
    }
}
