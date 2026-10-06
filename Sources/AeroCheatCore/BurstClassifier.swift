import Foundation

/// A workspace switch attributed to the mouse.
public struct MouseSwitch: Equatable {
    public let from: String
    public let to: String
    /// The user is going back to the workspace they were on before their previous switch.
    public let returnsToPrevious: Bool

    public init(from: String, to: String, returnsToPrevious: Bool = false) {
        self.from = from
        self.to = to
        self.returnsToPrevious = returnsToPrevious
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
}

public enum BurstVerdict: Equatable {
    case keyboard(binding: String)
    case mouse(MouseSwitch)
    case ignored(IgnoreReason)
}

/// Groups AeroSpace events into bursts and classifies each burst once it has settled.
///
/// Events less than `settle` seconds apart form a burst. A burst containing `binding-triggered`
/// is keyboard. A burst with a net workspace change, no binding and a recent mouse click is mouse.
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

    /// Closes the open burst, if any. Call it once the stream has been quiet for `settle`.
    public mutating func flush() -> BurstVerdict? {
        events.isEmpty ? nil : close()
    }

    private mutating func close() -> BurstVerdict {
        defer { events = [] }

        var binding: String?
        var transitions: [(from: String, to: String)] = []
        for entry in events {
            switch entry.event {
            case .bindingTriggered(let name, _): binding = binding ?? name
            case .focusedWorkspaceChanged(let prev, let workspace): transitions.append((prev, workspace))
            case .focusChanged, .modeChanged: break
            }
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
        guard let net else { return .ignored(.noWorkspaceChange) }
        guard isNetChange else {
            return .ignored(net.from == net.to && transitions.count > 1 ? .bounce : .noWorkspaceChange)
        }
        defer { lastSwitch = net }
        guard mode == "main" else { return .ignored(.modeNotMain) }
        guard events[0].input.sinceLastClick < mouseWindow else { return .ignored(.noRecentClick) }
        let returns = lastSwitch.map { $0.from == net.to && $0.to == net.from } ?? false
        return .mouse(MouseSwitch(from: net.from, to: net.to, returnsToPrevious: returns))
    }
}
