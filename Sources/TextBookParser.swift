import Foundation

/// 把 txt 文件解码并切成章节。全部是纯逻辑,可在后台线程调用。
enum TextBookParser {
    enum ImportError: LocalizedError, Equatable {
        case unreadable
        case undecodable
        case empty

        var errorDescription: String? {
            switch self {
            case .unreadable: return "无法读取这个文件"
            case .undecodable: return "无法识别文件编码(支持 UTF-8、UTF-16、GBK/GB18030)"
            case .empty: return "文件里没有可阅读的文字"
            }
        }
    }

    /// 没识别到章节标题时,每个分段大约多少字。
    static let chunkSize = 3000
    /// 超过这个长度的行不当作章节标题。
    static let maxHeadingLength = 40

    private static let headingPattern =
        #"^(第\s*[0-9零〇一二三四五六七八九十百千万两]+\s*[章节回卷集部篇]|(?i:chapter)\s*[0-9IVXivx]+|序章|楔子|引子|尾声|后记|番外)"#

    // MARK: - 导入

    /// 从文件导入一本书。文件来自"文件"App 时需要安全作用域访问权限。
    static func importBook(from url: URL) throws -> Book {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
        }
        guard let data = try? Data(contentsOf: url) else { throw ImportError.unreadable }
        return try makeBook(from: data, fileName: url.lastPathComponent)
    }

    static func makeBook(from data: Data, fileName: String) throws -> Book {
        guard let text = decode(data) else { throw ImportError.undecodable }
        let chapters = splitChapters(text)
        guard !chapters.isEmpty else { throw ImportError.empty }
        let name = (fileName as NSString).deletingPathExtension
        return Book(
            title: name.isEmpty ? "未命名" : name,
            author: "导入作品",
            chapters: chapters
        )
    }

    // MARK: - 解码

    /// 依次尝试 UTF-8(含 BOM)、UTF-16(含 BOM)、GB18030(兼容 GBK/GB2312)。
    static func decode(_ data: Data) -> String? {
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            return String(data: data.dropFirst(3), encoding: .utf8)
        }
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) {
            return String(data: data, encoding: .utf16)
        }
        if let text = String(data: data, encoding: .utf8) {
            return text
        }
        let gb18030 = CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
        )
        return String(data: data, encoding: String.Encoding(rawValue: gb18030))
    }

    // MARK: - 分章

    static func isHeading(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.count <= maxHeadingLength else { return false }
        return trimmed.range(of: headingPattern, options: .regularExpression) != nil
    }

    /// 按"第X章/节/回……"等标题分章;完全没有标题时按字数切成若干部分。
    static func splitChapters(_ rawText: String) -> [Chapter] {
        let text = rawText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        var chapters: [Chapter] = []
        var currentTitle: String?
        var buffer: [String] = []
        var allLines: [String] = []
        var sawHeading = false

        func flush() {
            let content = buffer.joined(separator: "\n")
            buffer.removeAll()
            guard !content.isEmpty else { return }
            chapters.append(Chapter(title: currentTitle ?? "序章", content: content))
        }

        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if isHeading(trimmed) {
                flush()
                currentTitle = trimmed
                sawHeading = true
            } else if !trimmed.isEmpty {
                buffer.append(trimmed)
                allLines.append(trimmed)
            }
        }
        flush()

        if sawHeading { return chapters }
        return chunk(lines: allLines)
    }

    private static func chunk(lines: [String]) -> [Chapter] {
        guard !lines.isEmpty else { return [] }
        var groups: [[String]] = []
        var current: [String] = []
        var count = 0
        for line in lines {
            current.append(line)
            count += line.count
            if count >= chunkSize {
                groups.append(current)
                current = []
                count = 0
            }
        }
        if !current.isEmpty { groups.append(current) }

        if groups.count == 1 {
            return [Chapter(title: "正文", content: groups[0].joined(separator: "\n"))]
        }
        return groups.enumerated().map { index, group in
            Chapter(title: "第 \(index + 1) 部分", content: group.joined(separator: "\n"))
        }
    }
}
