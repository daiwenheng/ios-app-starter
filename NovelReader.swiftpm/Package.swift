// swift-tools-version: 5.9

// 由 scripts/sync-playground.py 生成,请不要手改;改 Sources/ 后重新运行脚本。

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "NovelReader",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "NovelReader",
            targets: ["AppModule"],
            bundleIdentifier: "com.daiwenheng.novelreader.playground",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .asset("AppIcon"),
            accentColor: .asset("AccentColor"),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "."
        )
    ]
)
