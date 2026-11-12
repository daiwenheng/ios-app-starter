import SwiftUI

/// 启动页:一整块靛蓝色,中间是淡淡的大字"阅"。点"进入书房"后整块向上滑走。
struct WelcomeView: View {
    let onEnter: () -> Void

    var body: some View {
        ZStack {
            Color(hex: 0x2B3A67).ignoresSafeArea()

            Text("阅")
                .font(AppFont.display(420))
                .foregroundStyle(Color.white.opacity(0.09))
                .fixedSize()
                .offset(x: 70, y: 90)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                Text("阅书")
                    .font(AppFont.display(56))
                    .foregroundStyle(Color.white)
                Text("你自己的书房。\n书都存在这台设备上,不用联网。")
                    .font(.system(size: 17))
                    .lineSpacing(5)
                    .foregroundStyle(Color.white.opacity(0.78))
                    .padding(.top, 14)

                Button(action: onEnter) {
                    Text("进入书房")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x2B3A67))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.white))
                }
                .accessibilityIdentifier("enterButton")
                .padding(.top, 36)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 48)
            .frame(maxWidth: 520)
        }
    }
}
