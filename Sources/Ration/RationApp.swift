import SwiftUI

/// All real UI is owned by AppDelegate via a manual NSStatusItem/NSPopover
/// (see AppDelegate.swift for why). This scene exists only because `App`
/// requires at least one; it never shows a window.
@main
struct RationApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
