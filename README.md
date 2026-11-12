# 小说阅读器

一个本地 iOS 小说阅读器 App,使用 [ios-ci-workflows](https://github.com/wenjinliuu/ios-ci-workflows) 进行 CI 构建与测试。

## 功能

- **书架**:封面网格,最近读过的排最前,顶部"接着读"一键回到上次位置;支持搜索书名/作者;"管理"模式下可编辑信息、删除
- **传 TXT**:从"文件"App 选一个或多个 txt;自动识别 UTF-8、UTF-16、GBK/GB18030,按"第X章/节/回""Chapter N"分章,没有标题时按字数切段;选一个文件时先确认书名、作者、封面
- **写书**:从空白开始写一本书
- **书籍信息**:书名、作者、简介、封面图片(自动缩小),没有封面时用按 id 固定配色的大字封面
- **阅读页**:滚动阅读、记住位置;点屏幕呼出上下菜单;章末有上一章/下一章;可直接编辑正文
- **书签与笔记**:阅读页右上角"…"在当前段落加书签或写笔记,在目录里查看、跳转、滑动删除
- **目录**:搜索章节、正序/倒序、当前章高亮;编辑模式可插入、上移/下移、改名、删除、末尾添加章节
- **阅读设置**:字号、加粗、行距、字距、段距、左右/上下边距、字体颜色、对话染色(“…”和「…」)及颜色、主题(跟随系统/默认/护眼/夜间)
- **备份与恢复**:选书导出为文件或复制到剪贴板,从文件或剪贴板恢复(覆盖当前所有书);和网页版"阅书"的备份格式互通

## 代码结构

| 文件 | 作用 |
| --- | --- |
| `Book.swift` / `Annotations.swift` / `BookEditing.swift` / `BookDraft.swift` | 书、章节、书签、笔记;目录编辑;书籍信息表单数据 |
| `TextBookParser.swift` / `ReaderText.swift` / `DialogueHighlighter.swift` | txt 解码与分章、分段、对话切分 |
| `LibraryStore.swift` / `ReadingProgress.swift` / `ReaderSettings.swift` | 书架与进度存储、阅读设置 |
| `BackupCodec.swift` / `CoverImage.swift` / `ToastCenter.swift` | 备份编解码、封面处理、轻提示 |
| `Theme.swift` | 配色、字体、封面、按钮样式 |
| `WelcomeView` / `ContentView` / `BookFormView` / `BackupView` | 启动页、书架、书籍表单、备份页 |
| `ReaderView` / `ChapterTextView` / `CatalogView` / `ReaderSettingsView` | 阅读页、正文排版、目录、阅读设置 |
| `Tests/` | 逻辑测试:解析、存储、进度、设置、目录编辑、备份、对话染色 |

## 在 iPad 上用 Swift Playgrounds 运行

没有 Mac 时,可以在 iPad 上直接运行(需要 iPadOS 17+ 和免费的 Swift Playgrounds):

1. 用 Safari 下载 `NovelReader.swiftpm.zip`
2. 在"文件"里点压缩包解压,得到 `NovelReader.swiftpm`
3. 点开它,用 Swift Playgrounds 打开,点运行(▶)

`NovelReader.swiftpm` 的代码由 `scripts/sync-playground.py` 从 `Sources/` 同步生成,改了 `Sources/` 之后重新运行 `python3 scripts/sync-playground.py`,不要手改包里的文件。

## 开发方式

按 ios-ci-workflows Skill 工作流开发:改代码 → push → 看 Build & Test 报告 → 继续迭代。

本地不需要 Mac / Xcode。协作规则见 [AGENTS.md](AGENTS.md)。
