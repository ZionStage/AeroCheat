import AeroCheatCore
import AppKit
import SwiftUI

/// Discreet bubble in a screen corner, like a macOS notification banner. Never key, never main, ignores
/// the mouse, so showing it cannot move focus (which would make AeroSpace emit events and feed back into
/// active mode).
final class ToastPanel: NSPanel {
    enum Corner { case topLeft, topRight }

    /// Where the bubble sits. Switching to `.topLeft` is the only change needed to move it.
    static let corner: Corner = .topRight
    /// Inset from the screen's visible frame. The top inset clears SketchyBar (about 74 pt from the screen top).
    static let margins = NSSize(width: 16, height: 80)
    /// How long the bubble stays up; `ActiveModeController.selfFeedbackGuard` only has to stay well below it.
    static let duration: TimeInterval = 4
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
            let x = Self.corner == .topRight
                ? frame.maxX - size.width - Self.margins.width
                : frame.minX + Self.margins.width
            setFrameOrigin(NSPoint(x: x, y: frame.maxY - size.height - Self.margins.height))
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
            HStack(spacing: 4) {
                ForEach(Array(suggestion.binding.combo.keyCaps.enumerated()), id: \.offset) { _, cap in
                    switch cap.rendering(symbolAvailable: { NSImage(systemSymbolName: $0, accessibilityDescription: nil) != nil }) {
                    case .icon(let name): Image(systemName: name)
                    case .text(let string): Text(string)
                    }
                }
            }
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
