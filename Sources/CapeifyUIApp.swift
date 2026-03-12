import SwiftUI

@main
struct CapeifyUIApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 600, height: 350)
    }
}
