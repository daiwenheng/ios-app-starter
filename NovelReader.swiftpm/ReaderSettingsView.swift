import SwiftUI

/// 阅读设置:主题、字号、行距。设置对所有书通用。
struct ReaderSettingsView: View {
    @AppStorage(ReaderStyle.fontSizeKey) private var fontSize = ReaderStyle.defaultFontSize
    @AppStorage(ReaderStyle.lineSpacingKey) private var lineSpacing = ReaderStyle.defaultLineSpacing
    @AppStorage(ReaderStyle.themeKey) private var themeRaw = ReaderTheme.system.rawValue
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("主题") {
                    Picker("主题", selection: $themeRaw) {
                        ForEach(ReaderTheme.allCases) { theme in
                            Text(theme.displayName).tag(theme.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("themePicker")
                }

                Section("字号:\(Int(fontSize))") {
                    Slider(value: $fontSize, in: ReaderStyle.fontSizeRange, step: 1) {
                        Text("字号")
                    } minimumValueLabel: {
                        Text("小").font(.footnote)
                    } maximumValueLabel: {
                        Text("大").font(.title3)
                    }
                    .accessibilityIdentifier("fontSizeSlider")
                }

                Section("行距:\(Int(lineSpacing))") {
                    Slider(value: $lineSpacing, in: ReaderStyle.lineSpacingRange, step: 1) {
                        Text("行距")
                    } minimumValueLabel: {
                        Image(systemName: "text.alignleft").font(.footnote)
                    } maximumValueLabel: {
                        Image(systemName: "text.alignleft").font(.title3)
                    }
                    .accessibilityIdentifier("lineSpacingSlider")
                }

                Section {
                    Button("恢复默认") {
                        fontSize = ReaderStyle.defaultFontSize
                        lineSpacing = ReaderStyle.defaultLineSpacing
                        themeRaw = ReaderTheme.system.rawValue
                    }
                }
            }
            .navigationTitle("阅读设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
