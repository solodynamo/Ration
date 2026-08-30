import SwiftUI

@main
struct RationApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            PopoverContentView(appState: appState)
                .onAppear { appState.start() }
        } label: {
            MenuBarRing(fraction: appState.snapshot.windowFraction)
        }
        .menuBarExtraStyle(.window)
    }
}
