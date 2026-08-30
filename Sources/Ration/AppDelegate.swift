import AppKit

/// Without an Info.plist (this is a bare SPM executable, not an app bundle)
/// there's no LSUIElement flag to hide the Dock icon, so we do it in code.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
