import AeroCheatCore
import AeroCheatUI
import AppKit
import SwiftUI

/// Discreet bubble in a screen corner, like a macOS notification banner. Never key, never main, ignores
/// the mouse, so showing it cannot move focus (which would make AeroSpace emit events and feed back into
/// active mode).
final class ToastPanel: NSPanel {
    private var fadeOutDuration = BubbleStyle().fadeOutDuration
    private var hideWork: DispatchWorkItem?

    init() {
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

    /// Shows `suggestion` with the look and position `settings` describe, read afresh on every call.
    func show(_ suggestion: Suggestion, settings: DisplaySettings) {
        let style = BubbleStyle(settings: settings)
        fadeOutDuration = style.fadeOutDuration
        let hosting = NSHostingView(rootView: BubbleView(content: BubbleContent(suggestion: suggestion, settings: settings), style: style))
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
                context.duration = self?.fadeOutDuration ?? 0
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
