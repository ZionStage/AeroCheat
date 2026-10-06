import AeroCheatCore
import AeroCheatUI
import AppKit
import SwiftUI

/// Discreet bubble in a screen corner, like a macOS notification banner. Never key, never main, ignores
/// the mouse, so showing it cannot move focus (which would make AeroSpace emit events and feed back into
/// active mode).
final class ToastPanel: NSPanel {
    private let style: BubbleStyle
    private var hideWork: DispatchWorkItem?

    init(style: BubbleStyle = BubbleStyle()) {
        self.style = style
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 56),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func show(_ suggestion: Suggestion) {
        let hosting = NSHostingView(rootView: BubbleView(content: BubbleContent(suggestion: suggestion), style: style))
        let size = hosting.fittingSize
        contentView = hosting
        setContentSize(size)
        if let frame = NSScreen.main?.visibleFrame {
            setFrameOrigin(style.origin(for: size, in: frame))
        }
        hideWork?.cancel()
        alphaValue = 1
        orderFrontRegardless()
        let work = DispatchWorkItem { [weak self] in
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = self?.style.fadeOutDuration ?? 0
                self?.animator().alphaValue = 0
            }, completionHandler: { self?.orderOut(nil) })
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + style.duration, execute: work)
    }

    func dismiss() {
        hideWork?.cancel()
        orderOut(nil)
    }
}
