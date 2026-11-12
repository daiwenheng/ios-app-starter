import Foundation

/// 目录编辑:加章、插入、上下移、改名、删除。全部是对 `Book` 的纯数据操作。
extension Book {
    /// 在末尾添加一个空章节,返回它的序号。
    @discardableResult
    mutating func appendChapter(title: String) -> Int {
        chapters.append(Chapter(title: title, content: ""))
        return chapters.count - 1
    }

    /// 在第 `index` 章后面插入一个空章节,返回它的序号。
    @discardableResult
    mutating func insertChapter(title: String, after index: Int) -> Int {
        let position = min(max(index + 1, 0), chapters.count)
        chapters.insert(Chapter(title: title, content: ""), at: position)
        return position
    }

    /// 把第 `index` 章移动 `offset` 位(上移 -1,下移 +1),返回新序号;越界返回 nil。
    @discardableResult
    mutating func moveChapter(at index: Int, by offset: Int) -> Int? {
        let target = index + offset
        guard chapters.indices.contains(index), chapters.indices.contains(target) else { return nil }
        let chapter = chapters.remove(at: index)
        chapters.insert(chapter, at: target)
        return target
    }

    mutating func renameChapter(at index: Int, to title: String) {
        guard chapters.indices.contains(index) else { return }
        chapters[index].title = title
    }

    /// 删除一章,同时删掉这一章的书签和笔记。至少保留一章,否则返回 false。
    @discardableResult
    mutating func deleteChapter(at index: Int) -> Bool {
        guard chapters.count > 1, chapters.indices.contains(index) else { return false }
        let removed = chapters.remove(at: index)
        bookmarks.removeAll { $0.chapterID == removed.id }
        notes.removeAll { $0.chapterID == removed.id }
        return true
    }
}

/// 章节顺序变化后,"当前正在读的章节序号"该怎么跟着变。
enum ChapterIndexMath {
    /// 把 `from` 章移到 `to` 位置之后,原来读到 `current` 章,现在应该是第几章。
    static func afterMove(current: Int, from: Int, to: Int) -> Int {
        if current == from { return to }
        if from < to, current > from, current <= to { return current - 1 }
        if from > to, current >= to, current < from { return current + 1 }
        return current
    }

    /// 删掉第 `deleted` 章后(`newCount` 是删后的章数),当前章序号应该是多少。
    static func afterDelete(current: Int, deleted: Int, newCount: Int) -> Int {
        if current >= newCount { return max(newCount - 1, 0) }
        if deleted < current { return current - 1 }
        return current
    }
}
