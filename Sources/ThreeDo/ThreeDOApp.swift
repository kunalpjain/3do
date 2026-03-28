import SwiftUI

@main
struct ThreeDOApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup("3do") {
            ContentView()
                .environmentObject(appState)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Spaces") {
                Button("Space 1") { appState.switchWorkspace(to: 0) }
                    .keyboardShortcut("1", modifiers: .command)
                Button("Space 2") { appState.switchWorkspace(to: 1) }
                    .keyboardShortcut("2", modifiers: .command)
                Button("Space 3") { appState.switchWorkspace(to: 2) }
                    .keyboardShortcut("3", modifiers: .command)
                Button("Space 4") { appState.switchWorkspace(to: 3) }
                    .keyboardShortcut("4", modifiers: .command)
                Button("Space 5") { appState.switchWorkspace(to: 4) }
                    .keyboardShortcut("5", modifiers: .command)
                Button("Space 6") { appState.switchWorkspace(to: 5) }
                    .keyboardShortcut("6", modifiers: .command)
                Button("Space 7") { appState.switchWorkspace(to: 6) }
                    .keyboardShortcut("7", modifiers: .command)
                Button("Space 8") { appState.switchWorkspace(to: 7) }
                    .keyboardShortcut("8", modifiers: .command)
                Button("Space 9") { appState.switchWorkspace(to: 8) }
                    .keyboardShortcut("9", modifiers: .command)
            }
        }
    }
}
