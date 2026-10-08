import CoreGraphics
import Foundation

/// A workspace switch attributed to the mouse.
public struct MouseSwitch: Equatable {
    public let from: String
    public let to: String
    /// The user is going back to the workspace they were on before their previous switch.
    public let returnsToPrevious: Bool
    /// The display focus left and the one it reached, as AeroSpace numbers them, when the switch crossed displays.
    /// `fromMonitor` is `nil` while the previous display is unknown.
    public let fromMonitor: Int?
    public let toMonitor: Int?

    public init(from: String, to: String, returnsToPrevious: Bool = false, fromMonitor: Int? = nil, toMonitor: Int? = nil) {
        self.from = from
        self.to = to
        self.returnsToPrevious = returnsToPrevious
        self.fromMonitor = fromMonitor
        self.toMonitor = toMonitor
    }
}

/// A window dragged to another display: it now belongs to the workspace shown there, and keeps focus.
public struct WindowMove: Equatable {
    public let windowId: Int
    public let from: String
    public let to: String
    /// As in `MouseSwitch`: `fromMonitor` is `nil` while the previous display is unknown.
    public let fromMonitor: Int?
    public let toMonitor: Int

    public init(windowId: Int, from: String, to: String, fromMonitor: Int?, toMonitor: Int) {
        self.windowId = windowId
        self.from = from
        self.to = to
        self.fromMonitor = fromMonitor
        self.toMonitor = toMonitor
    }
}

/// A click that moved focus to another window of the same workspace.
public struct FocusSwitch: Equatable {
    public let windowId: Int
    public let workspace: String
    /// The window that had focus before the click.
    public let previousWindowId: Int
    /// Pointer position when the burst started, `nil` when unknown.
    public let pointer: CGPoint?

    public init(windowId: Int, workspace: String, previousWindowId: Int, pointer: CGPoint? = nil) {
        self.windowId = windowId
        self.workspace = workspace
        self.previousWindowId = previousWindowId
        self.pointer = pointer
    }
}

public enum IgnoreReason: Equatable {
    /// Another binding mode is active (only `main` is supported).
    case modeNotMain
    /// Focus-only burst, mode change, or initial state: no workspace switch to attribute.
    case noWorkspaceChange
    /// Workspace changed and changed back within the burst (focus bounce): net no change.
    case bounce
    /// Workspace changed without a binding and without a recent click: Cmd-Tab, Spotlight, rules, scripts.
    case noRecentClick
    /// A click happened, but a key or modifier came after it: Cmd-Tab, a launcher, a keyboard shortcut outside AeroSpace.
    case keyAfterClick
    /// A click on a notification: macOS brings the app to the front and AeroSpace follows it, which is not a mouse habit to correct.
    case notificationClick
    /// A click on a Dock icon: the app comes to the front and AeroSpace follows it. Only when the settings ignore the Dock.
    case dockClick
    /// Focus moved without a workspace change but the window it came from is unknown or absent, so nothing can be compared.
    case noFocusBaseline
    /// Focus ended on the window it started on, or on no window at all.
    case noFocusChange
}

public enum BurstVerdict: Equatable {
    case keyboard(binding: String)
    case mouse(MouseSwitch)
    /// A click moved focus within one workspace. Whether it is worth a suggestion depends on the window's layout.
    case mouseFocus(FocusSwitch)
    /// A drag moved the focused window to the workspace of another display.
    case mouseMove(WindowMove)
    case ignored(IgnoreReason)
}

/// Groups AeroSpace events into bursts and classifies each burst once it has settled.
///
/// Events less than `settle` seconds apart form a burst. A burst containing `binding-triggered`
/// is keyboard. A burst with a net workspace change, no binding and a recent mouse click is mouse. A burst with
/// only focus changes, no binding and a recent click is a focus candidate. A key pressed after the click rules both out.
/// Each display shows its own workspace, so a click on another display is a workspace switch; when the focused window
/// stays the same across that switch, the window was dragged there.
/// Timestamps are monotonic seconds supplied by the caller, so the type is deterministic in tests.
public struct BurstClassifier {
    public var settle: TimeInterval
    public var mouseWindow: TimeInterval

    private struct Entry {
        let time: TimeInterval
        let event: AeroEvent
        let input: InputRecency
    }

    private var events: [Entry] = []
    private var mode = "main"
    private var lastSwitch: (from: String, to: String)?
    /// Where focus was when the previous burst closed.
    private var focus: (windowId: Int, workspace: String)?
    /// The focused display as of the last `focused-monitor-changed`, `nil` before the first one or once forgotten.
    private var monitor: Int?

    /// The window focused when the last burst closed, `nil` for none. Read it right after a verdict to know where focus landed.
    public var focusedWindowId: Int? { focus.flatMap { $0.windowId == 0 ? nil : $0.windowId } }

    public init(settle: TimeInterval = 0.12, mouseWindow: TimeInterval = 0.8) {
        self.settle = settle
        self.mouseWindow = mouseWindow
    }

    /// Adds an event. Returns the verdict of the previous burst when this event starts a new one.
    /// `input` is the mouse recency sampled when the event arrived.
    public mutating func ingest(_ event: AeroEvent, at time: TimeInterval, input: InputRecency) -> BurstVerdict? {
        var verdict: BurstVerdict?
        if let last = events.last, time - last.time >= settle {
            verdict = close()
        }
        if case .modeChanged(let newMode) = event { mode = newMode }
        events.append(Entry(time: time, event: event, input: input))
        return verdict
    }

    /// Forgets where focus was and the focused display. Call it when events stop being observed, so a stale baseline
    /// never sets a step or reads a click as a window move.
    public mutating func forgetBaselines() {
        forgetFocus()
        monitor = nil
    }

    /// Forgets where focus was. Call it when a focus or workspace event is skipped.
    public mutating func forgetFocus() {
        focus = nil
    }

    /// Closes the open burst, if any. Call it once the stream has been quiet for `settle`.
    public mutating func flush() -> BurstVerdict? {
        events.isEmpty ? nil : close()
    }

    private mutating func close() -> BurstVerdict {
        defer { events = [] }

        var binding: String?
        var transitions: [(from: String, to: String)] = []
        var lastFocus: (windowId: Int, workspace: String)?
        var lastMonitor: Int?
        for entry in events {
            switch entry.event {
            case .bindingTriggered(let name, _): binding = binding ?? name
            case .focusedWorkspaceChanged(let prev, let workspace): transitions.append((prev, workspace))
            case .focusChanged(let windowId, let workspace): lastFocus = (windowId, workspace)
            case .focusedMonitorChanged(let monitorId, _): lastMonitor = monitorId
            case .modeChanged: break
            }
        }

        // A display change counts only if focus did not come back to the display it started on.
        let previousMonitor = monitor
        if let lastMonitor { monitor = lastMonitor }
        let newMonitor = lastMonitor.flatMap { $0 == previousMonitor ? nil : $0 }

        // Where focus was before this burst, then where it is now. A workspace change without a focus event
        // (an empty workspace) leaves focus on no window.
        let previousFocus = focus
        if let lastFocus {
            focus = lastFocus
        } else if let last = transitions.last {
            focus = (0, last.to)
        }

        // The net change of the whole burst: the first workspace left and the last one entered.
        let net = transitions.first.flatMap { first in
            transitions.last.map { (from: first.from, to: $0.to) }
        }
        let isNetChange = net.map { $0.from != $0.to } ?? false

        if let binding {
            if let net, isNetChange { lastSwitch = net }
            return .keyboard(binding: binding)
        }
        guard let net else { return classifyFocusOnly(from: previousFocus, to: lastFocus) }
        guard isNetChange else {
            return .ignored(net.from == net.to && transitions.count > 1 ? .bounce : .noWorkspaceChange)
        }
        defer { lastSwitch = net }
        guard mode == "main" else { return .ignored(.modeNotMain) }
        if let reason = inputRejection() { return .ignored(reason) }
        if let newMonitor, let previousFocus, previousFocus.windowId != 0, lastFocus?.windowId == previousFocus.windowId {
            return .mouseMove(WindowMove(
                windowId: previousFocus.windowId, from: net.from, to: net.to, fromMonitor: previousMonitor, toMonitor: newMonitor
            ))
        }
        let returns = lastSwitch.map { $0.from == net.to && $0.to == net.from } ?? false
        return .mouse(MouseSwitch(
            from: net.from, to: net.to, returnsToPrevious: returns,
            fromMonitor: newMonitor == nil ? nil : previousMonitor, toMonitor: newMonitor
        ))
    }

    /// A burst without a workspace change: a candidate only when focus moved to another window of the same workspace.
    private func classifyFocusOnly(from previous: (windowId: Int, workspace: String)?, to new: (windowId: Int, workspace: String)?) -> BurstVerdict {
        guard let new else { return .ignored(.noWorkspaceChange) }
        guard mode == "main" else { return .ignored(.modeNotMain) }
        guard let previous, previous.windowId != 0, previous.workspace == new.workspace else { return .ignored(.noFocusBaseline) }
        guard new.windowId != 0, new.windowId != previous.windowId else { return .ignored(.noFocusChange) }
        if let reason = inputRejection() { return .ignored(reason) }
        return .mouseFocus(FocusSwitch(
            windowId: new.windowId,
            workspace: new.workspace,
            previousWindowId: previous.windowId,
            pointer: events[0].input.pointer
        ))
    }

    /// Why the input sampled at the start of the burst rules out a mouse action, if it does.
    private func inputRejection() -> IgnoreReason? {
        let input = events[0].input
        guard input.sinceLastClick < mouseWindow else { return .noRecentClick }
        guard !input.keyFollowedClick else { return .keyAfterClick }
        guard !input.onNotification else { return .notificationClick }
        guard !input.onDock else { return .dockClick }
        return nil
    }
}
