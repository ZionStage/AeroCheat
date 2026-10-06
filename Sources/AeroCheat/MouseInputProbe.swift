import AeroCheatCore
import CoreGraphics

/// Reads how long ago the left mouse button was last pressed or released.
/// `secondsSinceLastEventType` needs no macOS permission, unlike an event tap or a global NSEvent monitor
/// (neither is used). The hardware counters ignore events synthesised by other tools. Counters rather than
/// button-state polling, because a tap-to-click is down and up within a few milliseconds.
enum MouseInputProbe {
    static func recency() -> InputRecency {
        InputRecency(
            sinceLeftMouseDown: CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .leftMouseDown),
            sinceLeftMouseUp: CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .leftMouseUp)
        )
    }
}
