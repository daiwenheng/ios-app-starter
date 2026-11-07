import SwiftUI

struct ContentView: View {
    @State private var selectedBook: Book? = nil
    
    private let books: [Book] = [
        Book(
            title: "情满四合院",
            author: "刘和平",
            chapters: [
                Chapter(title: "第一章 回家", content: "天下雪。\n\n周秉昆站在院门口，望着风雪中走来的人影。"),
                Chapter(title: "第二章 院里的事", content: "四合院里住着很多人。\n\n每一家都有自己的故事。")
            ]
        ),
        Book(
            title: "绿奴之路",
            author: "网络小说",
            chapters: [
                Chapter(title: "开篇", content: "这是一个关于成长的故事。\n\n从这里开始阅读吧。")
            ]
        ),
        Book(
            title: "示例短篇",
            author: "本地示例",
            chapters: [
                Chapter(title: "第一章", content: "这是一个用于演示的短篇小说。\n\n你可以在这里添加更多章节和内容。\n\n阅读界面支持上下滑动阅读。")
            ]
        )
    ]
    
    var body: some View {
        NavigationStack {
            List(books) { book in
                NavigationLink(value: book) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(book.title)
                            .font(.headline)
                        Text(book.author)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("小说阅读器")
            .navigationDestination(for: Book.self) { book in
                ChapterListView(book: book)
            }
        }
    }
}

struct ChapterListView: View {
    let book: Book
    
    var body: some View {
        List(book.chapters) { chapter in
            NavigationLink(value: chapter) {
                Text(chapter.title)
            }
        }
        .navigationTitle(book.title)
        .navigationDestination(for: Chapter.self) { chapter in
            ReaderView(chapter: chapter)
        }
    }
}

struct ReaderView: View {
    let chapter: Chapter
    
    var body: some View {
        ScrollView {
            Text(chapter.content)
                .font(.body)
                .lineSpacing(8)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(chapter.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ContentView()
}
