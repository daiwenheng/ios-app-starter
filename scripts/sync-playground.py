#!/usr/bin/env python3
"""把 Sources/ 同步成 iPad 上 Swift Playgrounds 能打开的包。

生成:
  NovelReader.swiftpm/      Swift Playgrounds 包(代码从 Sources/ 复制,去掉 #Preview)
  NovelReader.swiftpm.zip   同一个包的压缩文件,方便在 iPad 的 Safari 里直接下载

改了 Sources/ 之后重新运行:  python3 scripts/sync-playground.py
"""
import re
import shutil
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCES = ROOT / "Sources"
PACKAGE = ROOT / "NovelReader.swiftpm"
ARCHIVE = ROOT / "NovelReader.swiftpm.zip"

PACKAGE_SWIFT = """// swift-tools-version: 5.9

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
"""


def strip_previews(text: str) -> str:
    """去掉顶层的 #Preview { ... } 块(Playgrounds 里不需要,也可能不支持)。"""
    return re.sub(r"^#Preview \{\n.*?^\}\n?", "", text, flags=re.S | re.M).rstrip() + "\n"


def build_package() -> None:
    if PACKAGE.exists():
        shutil.rmtree(PACKAGE)
    PACKAGE.mkdir()
    (PACKAGE / "Package.swift").write_text(PACKAGE_SWIFT, encoding="utf-8")
    for source in sorted(SOURCES.glob("*.swift")):
        text = source.read_text(encoding="utf-8")
        (PACKAGE / source.name).write_text(strip_previews(text), encoding="utf-8")
    shutil.copytree(SOURCES / "Assets.xcassets", PACKAGE / "Assets.xcassets")


def build_archive() -> None:
    """固定时间戳,没改内容时压缩包字节不变,避免无意义的提交。"""
    if ARCHIVE.exists():
        ARCHIVE.unlink()
    with zipfile.ZipFile(ARCHIVE, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(PACKAGE.rglob("*")):
            arcname = f"{PACKAGE.name}/{path.relative_to(PACKAGE).as_posix()}"
            if path.is_dir():
                continue
            info = zipfile.ZipInfo(arcname, date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            archive.writestr(info, path.read_bytes())


if __name__ == "__main__":
    build_package()
    build_archive()
    count = len(list(PACKAGE.glob("*.swift")))
    print(f"{PACKAGE.name}: {count} 个 Swift 文件(含 Package.swift);{ARCHIVE.name}: {ARCHIVE.stat().st_size} 字节")
