import Foundation
import Observation
import SwiftUI

enum ReaderThemeKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case paper
    case eyeCare
    case night

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .paper: return "默认"
        case .eyeCare: return "护眼"
        case .night: return "夜间"
        }
    }
}

/// 阅读设置(对所有书通用)。取值范围和默认值与原网页版一致。
struct ReaderSettings: Codable, Equatable, Sendable {
    static let fontSizeRange: ClosedRange<Double> = 13...28
    static let lineHeightRange: ClosedRange<Double> = 1.2...2.6
    static let letterSpacingRange: ClosedRange<Double> = -1...3
    static let paraGapRange: ClosedRange<Double> = 0.2...2.5
    static let padXRange: ClosedRange<Double> = 0...40
    static let padYRange: ClosedRange<Double> = 0...60

    /// 字体颜色可选项(十六进制)。
    static let textColorOptions = ["#333333", "#000000", "#1F3A5F", "#2E4F3C", "#5C3A21"]
    /// 对话颜色可选项(十六进制)。
    static let dialogueColorOptions = ["#5B8C6F", "#3D7EAA", "#7B5EA7", "#A67B5B", "#C05A5A"]

    var fontSize: Double = 17
    var bold: Bool = false
    var lineHeight: Double = 1.8
    var letterSpacing: Double = 0
    var paraGap: Double = 1
    var padX: Double = 8
    var padY: Double = 25
    var textColorHex: String = "#333333"
    var dialogueHighlight: Bool = true
    var dialogueColorHex: String = "#5B8C6F"
    var theme: ReaderThemeKind = .system

    init() {}

    private enum CodingKeys: String, CodingKey {
        case fontSize, bold, lineHeight, letterSpacing, paraGap, padX, padY
        case textColorHex, dialogueHighlight, dialogueColorHex, theme
    }

    /// 字段缺失或取值不认识时用默认值,并把数值限制在合法范围内。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = ReaderSettings()
        fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize) ?? defaults.fontSize
        bold = try container.decodeIfPresent(Bool.self, forKey: .bold) ?? defaults.bold
        lineHeight = try container.decodeIfPresent(Double.self, forKey: .lineHeight) ?? defaults.lineHeight
        letterSpacing = try container.decodeIfPresent(Double.self, forKey: .letterSpacing) ?? defaults.letterSpacing
        paraGap = try container.decodeIfPresent(Double.self, forKey: .paraGap) ?? defaults.paraGap
        padX = try container.decodeIfPresent(Double.self, forKey: .padX) ?? defaults.padX
        padY = try container.decodeIfPresent(Double.self, forKey: .padY) ?? defaults.padY
        textColorHex = try container.decodeIfPresent(String.self, forKey: .textColorHex) ?? defaults.textColorHex
        dialogueHighlight = try container.decodeIfPresent(Bool.self, forKey: .dialogueHighlight) ?? defaults.dialogueHighlight
        dialogueColorHex = try container.decodeIfPresent(String.self, forKey: .dialogueColorHex) ?? defaults.dialogueColorHex
        let rawTheme = try container.decodeIfPresent(String.self, forKey: .theme)
        theme = rawTheme.flatMap { ReaderThemeKind(rawValue: $0) } ?? defaults.theme
        self = clamped()
    }

    static func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }

    func clamped() -> ReaderSettings {
        var copy = self
        copy.fontSize = Self.clamp(fontSize, to: Self.fontSizeRange)
        copy.lineHeight = Self.clamp(lineHeight, to: Self.lineHeightRange)
        copy.letterSpacing = Self.clamp(letterSpacing, to: Self.letterSpacingRange)
        copy.paraGap = Self.clamp(paraGap, to: Self.paraGapRange)
        copy.padX = Self.clamp(padX, to: Self.padXRange)
        copy.padY = Self.clamp(padY, to: Self.padYRange)
        return copy
    }

    /// 网页里的 line-height 是整行高度的倍数;SwiftUI 的 lineSpacing 是额外行距(点)。
    /// 系统字体本身大约占 1.2 倍字号,所以额外行距 = (倍数 - 1.2) × 字号。
    var extraLineSpacing: CGFloat {
        CGFloat(max(lineHeight - 1.2, 0) * fontSize)
    }

    /// 段落间距(点):网页里是 em,即字号的倍数。
    var paragraphSpacing: CGFloat {
        CGFloat(paraGap * fontSize)
    }
}

/// 阅读设置的存取。界面直接绑定 `settings`,改动后调用 `persist()` 保存。
@MainActor
@Observable
final class ReaderSettingsStore {
    static let defaultsKey = "reader.settings.v2"

    var settings: ReaderSettings

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.defaultsKey),
           let saved = try? JSONDecoder().decode(ReaderSettings.self, from: data) {
            settings = saved
        } else {
            settings = ReaderSettings()
        }
    }

    func update(_ change: (inout ReaderSettings) -> Void) {
        var copy = settings
        change(&copy)
        settings = copy.clamped()
        persist()
    }

    func persist() {
        if let data = try? JSONEncoder().encode(settings.clamped()) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }

    func reset() {
        settings = ReaderSettings()
        persist()
    }
}
