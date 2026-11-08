# 小说阅读器

一个本地 iOS 小说阅读器 App,使用 [ios-ci-workflows](https://github.com/wenjinliuu/ios-ci-workflows) 进行 CI 构建与测试。

## 功能

- **书架**:书保存在本机,支持滑动删除;第一次启动自带两本示例书(使用说明、示例短篇)
- **导入 txt**:点右上角 + 从"文件"App 选择一个或多个 txt
  - 自动识别 UTF-8、UTF-16、GBK/GB18030 编码
  - 按"第X章/节/回……""Chapter N"等标题自动分章;没有标题时按字数切成若干部分
- **目录**:每本书一个目录页,顶部"继续阅读"回到上次读到的章节和位置
- **阅读页**:滚动阅读,上一章/下一章,自动记住阅读位置
- **阅读设置**:字号、行距、主题(跟随系统 / 白天 / 护眼 / 夜间),所有书通用

## 代码结构

| 文件 | 作用 |
| --- | --- |
| `Sources/Book.swift` | `Book` / `Chapter` 模型(可持久化) |
| `Sources/TextBookParser.swift` | txt 解码与分章 |
| `Sources/LibraryStore.swift` | 书架与阅读进度的存储 |
| `Sources/ReadingProgress.swift` | 阅读进度、阅读页导航目标 |
| `Sources/ReaderText.swift` / `ReaderStyle.swift` | 阅读页的分段、字号/主题等外观设置 |
| `Sources/ContentView.swift` | 书架页(含导入) |
| `Sources/ChapterListView.swift` / `ReaderView.swift` / `ReaderSettingsView.swift` | 目录、阅读页、阅读设置 |
| `Tests/` | 逻辑测试:解析、存储、进度、样式 |

## 在 iPad 上用 Swift Playgrounds 运行

没有 Mac 时,可以在 iPad 上直接运行(需要 iPadOS 17+ 和免费的 Swift Playgrounds):

1. 用 Safari 下载 `NovelReader.swiftpm.zip`
2. 在"文件"里点压缩包解压,得到 `NovelReader.swiftpm`
3. 点开它,用 Swift Playgrounds 打开,点运行(▶)

`NovelReader.swiftpm` 的代码由 `scripts/sync-playground.py` 从 `Sources/` 同步生成,改了 `Sources/` 之后重新运行 `python3 scripts/sync-playground.py`,不要手改包里的文件。

## 开发方式

按 ios-ci-workflows Skill 工作流开发:改代码 → push → 看 Build & Test 报告 → 继续迭代。

本地不需要 Mac / Xcode。协作规则见 [AGENTS.md](AGENTS.md)。
