import SwiftUI

/// 阅读设置:字体大小、行距、字距、段距、边距、字体颜色、对话染色、主题。所有书通用。
struct ReaderSettingsView: View {
    @Environment(ReaderSettingsStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                Section("主题") {
                    Picker("主题", selection: $store.settings.theme) {
                        ForEach(ReaderThemeKind.allCases) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("themePicker")
                }

                Section("文字") {
                    slider("字号", value: $store.settings.fontSize, range: ReaderSettings.fontSizeRange, step: 1, format: "%.0f")
                    Toggle("加粗", isOn: $store.settings.bold)
                    colorRow("字体颜色", options: ReaderSettings.textColorOptions, selection: $store.settings.textColorHex)
                }

                Section("排版") {
                    slider("行距", value: $store.settings.lineHeight, range: ReaderSettings.lineHeightRange, step: 0.1, format: "%.1f")
                    slider("字距", value: $store.settings.letterSpacing, range: ReaderSettings.letterSpacingRange, step: 0.5, format: "%.1f")
                    slider("段距", value: $store.settings.paraGap, range: ReaderSettings.paraGapRange, step: 0.1, format: "%.1f")
                    slider("左右边距", value: $store.settings.padX, range: ReaderSettings.padXRange, step: 1, format: "%.0f")
                    slider("上下边距", value: $store.settings.padY, range: ReaderSettings.padYRange, step: 1, format: "%.0f")
                }

                Section("对话") {
                    Toggle("对话染色", isOn: $store.settings.dialogueHighlight)
                    if store.settings.dialogueHighlight {
                        colorRow("对话颜色", options: ReaderSettings.dialogueColorOptions, selection: $store.settings.dialogueColorHex)
                    }
                }

                Section {
                    Button("恢复默认设置", role: .destructive) { store.reset() }
                }
            }
            .navigationTitle("阅读设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .onChange(of: store.settings) { _, _ in store.persist() }
        }
        .tint(Palette.accent)
    }

    private func slider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        format: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .foregroundStyle(Palette.inkSoft)
                    .monospacedDigit()
            }
            Slider(value: value, in: range, step: step)
        }
    }

    private func colorRow(_ title: String, options: [String], selection: Binding<String>) -> some View {
        HStack {
            Text(title)
            Spacer()
            HStack(spacing: 10) {
                ForEach(options, id: \.self) { hex in
                    Button {
                        selection.wrappedValue = hex
                    } label: {
                        Circle()
                            .fill(Color(hexString: hex))
                            .frame(width: 26, height: 26)
                            .overlay(
                                Circle().stroke(Palette.accent, lineWidth: selection.wrappedValue == hex ? 2.5 : 0)
                                    .padding(-3)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(hex)
                }
            }
        }
    }
}
