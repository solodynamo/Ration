import AppKit
import SwiftUI
import Combine

/// Owns the status item directly via AppKit rather than SwiftUI's
/// `MenuBarExtra` scene. `MenuBarExtra` is unreliable in an app bundle
/// assembled outside Xcode and ad-hoc signed (see Scripts/build_app.sh) —
/// it can silently fail to add a status item at all, with no error and a
/// perfectly healthy running process. NSStatusItem is the decades-old,
/// directly-debuggable primitive that every menu bar app used before
/// MenuBarExtra existed, so we use it instead of chasing SwiftUI scene
/// internals we can't inspect.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var appState: AppState?
    private var snapshotCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let appState = AppState()
        self.appState = appState

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.target = self
        item.button?.action = #selector(togglePopover(_:))
        statusItem = item

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: PopoverContentView(appState: appState))
        self.popover = popover

        renderStatusIcon()
        snapshotCancellable = appState.$snapshot
            .combineLatest(appState.$providerAvailable)
            .sink { [weak self] _, _ in self?.renderStatusIcon() }

        appState.start()
    }

    /// Rasterizes the SwiftUI ring into an NSImage for the status item
    /// button. NSStatusItem has no SwiftUI-native content slot, so this is
    /// the bridge between the AppKit status item and the existing
    /// SwiftUI-drawn `MenuBarRing`.
    @MainActor
    private func renderStatusIcon() {
        guard let appState, let button = statusItem?.button else { return }
        let renderer = ImageRenderer(content: MenuBarRing(fraction: appState.snapshot.windowFraction))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        button.image = renderer.nsImage
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button, let popover else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
