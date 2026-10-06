import AeroCheatCore
import AppKit
import SwiftUI

/// Discreet bubble at the bottom centre of the screen. Never key, never main, ignores the mouse,
/// so showing it cannot move focus (which would make AeroSpace emit events and feed back into active mode).
final class ToastPanel: NSPanel {
    private static let duration: TimeInterval = 2.2
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

    func show(_ suggestion: Suggestion) {
        let hosting = NSHostingView(rootView: ToastView(suggestion: suggestion))
        let size = hosting.fittingSize
        contentView = hosting
        setContentSize(size)
        if let frame = NSScreen.main?.visibleFrame {
            setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.minY + 48))
        }
        hideWork?.cancel()
        alphaValue = 1
        orderFrontRegardless()
        let work = DispatchWorkItem { [weak self] in
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                self?.animator().alphaValue = 0
            }, completionHandler: { self?.orderOut(nil) })
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.duration, execute: work)
    }

    func dismiss() {
        hideWork?.cancel()
        orderOut(nil)
    }
}

private struct ToastView: View {
    let suggestion: Suggestion

    var body: some View {
        HStack(spacing: 12) {
            Text(suggestion.keys)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 7).fill(.quaternary))
            VStack(alignment: .leading, spacing: 1) {
                Text(suggestion.title).font(.callout)
                if let hint = suggestion.hint {
                    Text(hint).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .fixedSize()
    }
}
