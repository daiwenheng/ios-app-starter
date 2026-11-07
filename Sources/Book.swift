import Foundation

struct Book: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let author: String
    let chapters: [Chapter]
}

struct Chapter: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let content: String
}
