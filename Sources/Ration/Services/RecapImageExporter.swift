import SwiftUI
import AppKit

/// Turns the recap card into an actual image file/clipboard item. Ration
/// has no network layer and no accounts — sharing happens by the user
/// pasting or dragging this into whatever app they want (Slack, X,
/// Messages), not by Ration uploading anything anywhere itself.
@MainActor
enum RecapImageExporter {
    static func renderImage(for card: RecapCardView) -> NSImage? {
        let renderer = ImageRenderer(content: card)
        renderer.scale = 2 // crisp on retina regardless of the viewer's display
        return renderer.nsImage
    }

    static func copyToClipboard(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }

    /// Returns true if the user actually saved (vs. cancelling the panel).
    @discardableResult
    static func saveToDisk(_ image: NSImage, suggestedName: String) -> Bool {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:])
        else { return false }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return false }
        do {
            try pngData.write(to: url)
            return true
        } catch {
            return false
        }
    }
}
