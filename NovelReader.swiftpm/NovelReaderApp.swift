import SwiftUI

@main
struct NovelReaderApp: App {
    @State private var library = LibraryStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(library)
        }
    }
}
