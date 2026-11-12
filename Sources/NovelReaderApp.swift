import SwiftUI

@main
struct NovelReaderApp: App {
    @State private var library = LibraryStore()
    @State private var readerSettings = ReaderSettingsStore()
    @State private var toast = ToastCenter()
    @State private var showingWelcome = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                if showingWelcome {
                    WelcomeView {
                        withAnimation(.easeInOut(duration: 0.5)) { showingWelcome = false }
                    }
                    .transition(.move(edge: .top))
                    .zIndex(1)
                }
            }
            .environment(library)
            .environment(readerSettings)
            .environment(toast)
        }
    }
}
