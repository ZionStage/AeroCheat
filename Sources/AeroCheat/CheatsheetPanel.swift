import AppKit
import SwiftUI

/// Borderless floating panel that can take keyboard focus without a title bar.
final class CheatsheetPanel: NSPanel {
    var onDismiss: (() -> Void)?

    init(model: CheatsheetModel) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        contentView = NSHostingView(rootView: CheatsheetView(model: model).clipShape(RoundedRectangle(cornerRadius: 14)))
    }

    override var canBecomeKey: Bool { true }

    /// Escape, forwarded by the responder chain from the search field.
    override func cancelOperation(_ sender: Any?) {
        onDismiss?()
    }
}
