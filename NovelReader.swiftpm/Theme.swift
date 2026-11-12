import SwiftUI
import UIKit

// MARK: - 颜色

extension Color {
    /// 0xRRGGBB
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// 解析 "#RRGGBB";格式不对时用 fallback。
    init(hexString: String, fallback: UInt32 = 0x333333) {
        let cleaned = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        self.init(hex: UInt32(cleaned, radix: 16) ?? fallback)
    }
}

/// 整个 App 的配色:冷灰白的底、墨色字、靛蓝做强调色,深色模式自动切换。
/// 想换整体配色,只改这里。
enum Palette {
    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }

    /// 页面底色
    static let mist = dynamic(light: 0xEEF1F4, dark: 0x0F1216)
    /// 面板、输入框底色
    static let surface = dynamic(light: 0xFFFFFF, dark: 0x1A1E24)
    /// 正文墨色
    static let ink = dynamic(light: 0x14181F, dark: 0xECEFF3)
    /// 次要文字
    static let inkSoft = dynamic(light: 0x5D6672, dark: 0x9AA3AF)
    /// 分割线
    static let line = dynamic(light: 0xD5DAE0, dark: 0x2A3039)
    /// 强调色(靛蓝)
    static let accent = dynamic(light: 0x2B3A67, dark: 0x8FA3E0)
    /// 强调色上的文字
    static let onAccent = dynamic(light: 0xFFFFFF, dark: 0x0F1216)
    /// 删除等危险操作
    static let danger = dynamic(light: 0xC8472F, dark: 0xF08A73)
}

// MARK: - 字体

enum AppFont {
    /// 封面上的大字和标题:宋体黑体。
    static func display(_ size: CGFloat) -> Font {
        .custom("Songti SC", size: size).weight(.black)
    }

    /// 阅读正文。
    static func reading(_ size: CGFloat, bold: Bool = false) -> Font {
        .custom("Songti SC", size: size).weight(bold ? .bold : .regular)
    }
}

// MARK: - 封面

/// 8 种平涂封面色。每本书按自己的 id 固定取一种,不受书名修改影响。
enum CoverHue {
    static let colors: [UInt32] = [
        0x2B3A67, // 靛蓝
        0xC8472F, // 朱红
        0xA9700F, // 赭黄
        0x1F7A74, // 青绿
        0x6B2D5C, // 紫
        0x2F5D3A, // 墨绿
        0x44505E, // 石板
        0xB8465E, // 玫红
    ]

    static func index(for id: UUID) -> Int {
        Int(id.uuid.0) % colors.count
    }

    static func color(for id: UUID) -> Color {
        Color(hex: colors[index(for: id)])
    }
}

/// 封面上的大字:书名的第一个字(跳过空白和书名号);书名为空时用"书"。
func coverGlyph(for title: String) -> String {
    let skipped: Set<Character> = ["《", "》", "「", "」", "“", "”", "\"", "'"]
    let first = title.first { !$0.isWhitespace && !skipped.contains($0) }
    return first.map(String.init) ?? "书"
}

/// 书的封面:有图片用图片,没有就是一整块颜色加一个巨大的字。
struct BookCoverView: View {
    let bookID: UUID
    let title: String
    let author: String
    let image: UIImage?

    var body: some View {
        Color.clear
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    generated
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .accessibilityElement()
            .accessibilityLabel(title)
    }

    private var generated: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .bottomTrailing) {
                CoverHue.color(for: bookID)
                Text(coverGlyph(for: title))
                    .font(AppFont.display(width * 1.05))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .offset(x: width * 0.12, y: width * 0.12)
                    .lineLimit(1)
                    .fixedSize()
                Text(author)
                    .font(.system(size: max(width * 0.075, 8), weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .lineLimit(1)
                    .padding(width * 0.09)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .clipped()
        }
    }
}

// MARK: - 按钮与输入框

/// 实心强调色按钮
struct SolidButtonStyle: ButtonStyle {
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 14 : 16, weight: .semibold))
            .foregroundStyle(Palette.onAccent)
            .padding(.horizontal, compact ? 14 : 22)
            .padding(.vertical, compact ? 8 : 13)
            .background(RoundedRectangle(cornerRadius: 4).fill(Palette.accent))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// 描边按钮;`selected` 为 true 时反色(用于"管理"这种开关状态)。
struct OutlineButtonStyle: ButtonStyle {
    var selected = false
    var destructive = false

    func makeBody(configuration: Configuration) -> some View {
        let tint = destructive ? Palette.danger : Palette.ink
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(selected ? Palette.onAccent : tint)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 4).fill(selected ? Palette.accent : Color.clear))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(selected ? Color.clear : Palette.line, lineWidth: 1.5)
            )
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// 输入框外观
struct FieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 4).fill(Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.line, lineWidth: 1))
    }
}

extension View {
    func field() -> some View {
        modifier(FieldStyle())
    }

    /// 在这个视图上方显示全局轻提示(弹窗里也要加一次,否则会被弹窗盖住)。
    func toastOverlay() -> some View {
        modifier(ToastOverlayModifier())
    }
}

private struct ToastOverlayModifier: ViewModifier {
    @Environment(ToastCenter.self) private var toast

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let message = toast.message {
                    Text(message)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color(hex: 0x14181F, opacity: 0.94)))
                        .padding(.bottom, 96)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: toast.message)
    }
}

// MARK: - 阅读页配色

/// 阅读页某个主题下的实际颜色。
struct ReaderPalette: Equatable {
    let background: Color
    let text: Color
    let secondary: Color
    let bar: Color
    let isDark: Bool

    static func resolve(_ kind: ReaderThemeKind, systemIsDark: Bool) -> ReaderPalette {
        switch kind {
        case .system:
            return resolve(systemIsDark ? .night : .paper, systemIsDark: systemIsDark)
        case .paper:
            return ReaderPalette(
                background: Color(hex: 0xFAFAF8), text: Color(hex: 0x333333),
                secondary: Color(hex: 0x8A9099), bar: Color(hex: 0xFFFFFF), isDark: false
            )
        case .eyeCare:
            return ReaderPalette(
                background: Color(hex: 0xCFE8D3), text: Color(hex: 0x2B3A2F),
                secondary: Color(hex: 0x5E7A65), bar: Color(hex: 0xDDF0E0), isDark: false
            )
        case .night:
            return ReaderPalette(
                background: Color(hex: 0x14171C), text: Color(hex: 0xB9C0CA),
                secondary: Color(hex: 0x6C7581), bar: Color(hex: 0x1D2128), isDark: true
            )
        }
    }
}
