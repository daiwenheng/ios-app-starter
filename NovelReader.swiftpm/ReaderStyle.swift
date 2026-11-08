import SwiftUI

/// 阅读外观的取值范围、默认值和存储键(用 @AppStorage 保存,所有书通用)。
enum ReaderStyle {
    static let fontSizeKey = "reader.fontSize"
    static let lineSpacingKey = "reader.lineSpacing"
    static let themeKey = "reader.theme"

    static let fontSizeRange: ClosedRange<Double> = 12...36
    static let lineSpacingRange: ClosedRange<Double> = 2...20
    static let defaultFontSize: Double = 19
    static let defaultLineSpacing: Double = 8

    static func clampedFontSize(_ value: Double) -> Double {
        min(max(value, fontSizeRange.lowerBound), fontSizeRange.upperBound)
    }

    static func clampedLineSpacing(_ value: Double) -> Double {
        min(max(value, lineSpacingRange.lowerBound), lineSpacingRange.upperBound)
    }
}

enum ReaderTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case sepia
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "白天"
        case .sepia: return "护眼"
        case .dark: return "夜间"
        }
    }

    var background: Color {
        switch self {
        case .system: return Color(uiColor: .systemBackground)
        case .light: return Color(red: 1.0, green: 1.0, blue: 1.0)
        case .sepia: return Color(red: 0.96, green: 0.93, blue: 0.84)
        case .dark: return Color(red: 0.09, green: 0.09, blue: 0.10)
        }
    }

    var foreground: Color {
        switch self {
        case .system: return Color.primary
        case .light: return Color(red: 0.10, green: 0.10, blue: 0.10)
        case .sepia: return Color(red: 0.24, green: 0.19, blue: 0.12)
        case .dark: return Color(red: 0.80, green: 0.80, blue: 0.78)
        }
    }

    /// 为 nil 表示跟随系统。
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light, .sepia: return .light
        case .dark: return .dark
        }
    }
}
