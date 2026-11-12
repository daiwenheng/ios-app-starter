# 阅书(网页版)

`docs/` 是一个纯网页的本地书房,可以在 iPhone / iPad 的 Safari 里"添加到主屏幕",像 App 一样全屏使用,断网也能用。书都存在这台设备的浏览器里。

功能:传 TXT(UTF-8/UTF-16/GBK 自动识别、自动分章)、写书、封面与简介、书架搜索与管理、阅读页(滚动、记住位置、正文编辑)、书签与笔记、目录(搜索/排序/插入/移动/改名/删除)、阅读设置(字号、行距、字距、段距、边距、字色、对话染色、主题)、备份与恢复(和旧版"阅书"备份互通)。

## 发布(GitHub Pages)

仓库 Settings → Pages → Build and deployment → Source 选 "Deploy from a branch",Branch 选这个分支,文件夹选 `/docs`,保存。约一分钟后访问 `https://<用户名>.github.io/ios-app-starter/`。

在 iPhone / iPad 的 Safari 打开后:分享 → 添加到主屏幕。

改了 `docs/` 里的文件后,把 `docs/sw.js` 里的 `VERSION` 加一,已安装的 App 才会更新缓存。

---

# 小说阅读器

一个简单的 iOS 小说阅读器 App，使用 [ios-ci-workflows](https://github.com/wenjinliuu/ios-ci-workflows) 进行 CI 构建与测试。

## 功能

- 书籍列表
- 章节列表
- 阅读页面（滚动阅读）
- 目前内置了示例小说内容

## 开发方式

按 ios-ci-workflows Skill 工作流开发：改代码 → push → 看 Build & Test 报告 → 继续迭代。

本地不需要 Mac / Xcode。
