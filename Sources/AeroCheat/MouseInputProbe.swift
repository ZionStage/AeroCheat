import AeroCheatCore
import CoreGraphics
import Foundation

/// Reads how long ago the left mouse button, a key or a modifier was last used, and where the pointer is.
/// `secondsSinceLastEventType` and `CGEvent(source: nil)` need no macOS permission, unlike an event tap or a global
/// NSEvent monitor (neither is used). The counters carry no key content. The hardware counters ignore events
/// synthesised by other tools. Counters rather than button-state polling, because a tap-to-click is down and up
/// within a few milliseconds.
enum MouseInputProbe {
    static func recency() -> InputRecency {
        func since(_ type: CGEventType) -> TimeInterval {
            CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: type)
        }
        return InputRecency(
            sinceLeftMouseDown: since(.leftMouseDown),
            sinceLeftMouseUp: since(.leftMouseUp),
            sinceKeyDown: since(.keyDown),
            sinceFlagsChanged: since(.flagsChanged),
            pointer: CGEvent(source: nil)?.location
        )
    }
}
