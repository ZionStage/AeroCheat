import CoreGraphics
import Foundation

public enum FocusDirection: String, Hashable {
    case left, right, up, down
}

/// A display one step away in AeroSpace's order of displays (`next` and `prev` in `focus-monitor` and `move-node-to-monitor`).
public enum MonitorStep: String, Hashable {
    case next, prev

    /// The step from one AeroSpace monitor number to the other, `nil` unless both are known and adjacent.
    public init?(from: Int?, to: Int?) {
        guard let from, let to else { return nil }
        switch to - from {
        case 1: self = .next
        case -1: self = .prev
        default: return nil
        }
    }
}

/// A canonical AeroSpace action, enough to tell which binding performs it.
public enum Action: Hashable, CustomStringConvertible {
    case workspace(String)
    case workspaceBackAndForth
    case focus(FocusDirection)
    case moveToWorkspace(String)
    case focusMonitor(MonitorStep)
    case moveToMonitor(MonitorStep)
    case other(String)

    /// Canonical form of one command: `--flags` are dropped, `workspace next|prev` stays `other`,
    /// and so does `focus` with anything but a plain direction (`dfs-next`, a window id). Only `next` and `prev`
    /// are kept for the monitor commands: a direction or a name cannot be checked against what the mouse did.
    public init(command: String) {
        let tokens = command.split(separator: " ").map(String.init)
        guard let head = tokens.first else { self = .other(command); return }
        let args = tokens.dropFirst().filter { !$0.hasPrefix("--") }
        switch head {
        case "workspace" where args.count == 1 && !["next", "prev"].contains(args[0]):
            self = .workspace(args[0])
        case "workspace-back-and-forth" where args.isEmpty:
            self = .workspaceBackAndForth
        case "focus" where args.count == 1 && FocusDirection(rawValue: args[0]) != nil:
            self = .focus(FocusDirection(rawValue: args[0])!)
        case "move-node-to-workspace" where args.count == 1 && !["next", "prev"].contains(args[0]):
            self = .moveToWorkspace(args[0])
        case "focus-monitor" where args.count == 1 && MonitorStep(rawValue: args[0]) != nil:
            self = .focusMonitor(MonitorStep(rawValue: args[0])!)
        case "move-node-to-monitor" where args.count == 1 && MonitorStep(rawValue: args[0]) != nil:
            self = .moveToMonitor(MonitorStep(rawValue: args[0])!)
        default:
            self = .other(command)
        }
    }

    public var description: String {
        switch self {
        case .workspace(let name): return "workspace \(name)"
        case .workspaceBackAndForth: return "workspace-back-and-forth"
        case .focus(let direction): return "focus \(direction.rawValue)"
        case .moveToWorkspace(let name): return "move-node-to-workspace \(name)"
        case .focusMonitor(let step): return "focus-monitor \(step.rawValue)"
        case .moveToMonitor(let step): return "move-node-to-monitor \(step.rawValue)"
        case .other(let command): return command
        }
    }
}

/// What made AeroCheat suggest a shortcut; a display can vary per trigger.
public enum SuggestionTrigger: Equatable {
    /// A mouse-driven switch to another workspace.
    case workspaceSwitch
    /// A mouse-driven focus change to another window of the same workspace.
    case focusChange
    /// A window dragged to another display.
    case windowMove
}

/// What to tell the user after a mouse-driven switch.
public struct Suggestion: Equatable {
    /// The second binding of a pair, such as focus right next to focus left.
    public struct Companion: Equatable {
        public let action: Action
        public let binding: Binding

        public init(action: Action, binding: Binding) {
            self.action = action
            self.binding = binding
        }
    }

    public let action: Action
    public let binding: Binding
    /// Binding that toggles back to the previous workspace, when relevant and configured.
    public let backAndForth: Binding?
    public let companion: Companion?
    public let trigger: SuggestionTrigger

    public init(
        action: Action,
        binding: Binding,
        backAndForth: Binding? = nil,
        companion: Companion? = nil,
        trigger: SuggestionTrigger = .workspaceSwitch
    ) {
        self.action = action
        self.binding = binding
        self.backAndForth = backAndForth
        self.companion = companion
        self.trigger = trigger
    }

    /// Identity used by cooldowns and learning: the binding, the first one of a pair.
    public var key: String { binding.combo.canonical }
    /// Other bindings that perform the suggestion's job; pressing one counts as having learned it.
    public var relatedKeys: [String] { companion.map { [$0.binding.combo.canonical] } ?? [] }
    public var keys: String { binding.combo.display }
    public var title: String {
        switch action {
        case .workspace(let name): return "switch to workspace \(name)"
        case .moveToWorkspace(let name): return "move window to workspace \(name)"
        case .focusMonitor(let step): return "focus the \(step == .next ? "next" : "previous") display"
        case .moveToMonitor(let step): return "move window to the \(step == .next ? "next" : "previous") display"
        default: return action.description
        }
    }
    public var hint: String? {
        if let companion { return "or \(companion.binding.combo.display) to \(companion.action.description)" }
        return backAndForth.map { "or \($0.combo.display) to toggle back" }
    }

    /// One-line form for the menu and logs.
    public var summary: String { "\(keys) — \(title)" }
}

/// Maps a detected action to the binding that performs it, from the already parsed config.
public struct ActionResolver {
    private var index: [Action: Binding] = [:]

    /// Indexes the single-command bindings of one mode; a chained binding is not equal to one action.
    /// When two bindings perform the same action, the first in file order wins.
    public init(mode: BindingMode?) {
        for binding in mode?.bindings ?? [] where binding.commands.count == 1 {
            let action = Action(command: binding.commands[0])
            if index[action] == nil { index[action] = binding }
        }
    }

    /// Uses the `main` mode, the only one active mode watches.
    public init(modes: [BindingMode]) {
        self.init(mode: modes.first { $0.name == "main" })
    }

    public func binding(for action: Action) -> Binding? { index[action] }

    /// `nil` when the config has no binding for the switch: nothing the user could press, so stay silent.
    /// A switch to another display falls back on `focus-monitor next|prev` when no binding names the workspace.
    public func suggestion(for mouseSwitch: MouseSwitch) -> Suggestion? {
        let action = Action.workspace(mouseSwitch.to)
        if let binding = index[action] {
            let back = mouseSwitch.returnsToPrevious ? index[.workspaceBackAndForth] : nil
            return Suggestion(action: action, binding: binding, backAndForth: back)
        }
        guard let step = MonitorStep(from: mouseSwitch.fromMonitor, to: mouseSwitch.toMonitor),
              let binding = index[.focusMonitor(step)] else { return nil }
        return Suggestion(action: .focusMonitor(step), binding: binding)
    }

    /// The binding that sends a window where the mouse dragged it: `move-node-to-workspace` with the workspace of
    /// the display it landed on, else `move-node-to-monitor next|prev`. `nil` when the config has neither.
    public func suggestion(for move: WindowMove) -> Suggestion? {
        let candidates = [Action.moveToWorkspace(move.to)]
            + (MonitorStep(from: move.fromMonitor, to: move.toMonitor).map { [Action.moveToMonitor($0)] } ?? [])
        for action in candidates {
            if let binding = index[action] { return Suggestion(action: action, binding: binding, trigger: .windowMove) }
        }
        return nil
    }

    /// Whether the config binds any focus direction. Without one a focus suggestion is impossible.
    public var hasFocusBindings: Bool {
        [FocusDirection.left, .right, .up, .down].contains { index[.focus($0)] != nil }
    }

    /// The suggestion for a click that moved focus within a workspace, from the layout of the window it landed on.
    /// `windowFrame` is that window's frame in the same coordinates as `focus.pointer`.
    /// `nil` (stay silent) when there is no direction to point to or no binding for it, for floating and
    /// native-fullscreen windows, and for a direct click: in tiles the pointer lands inside the window it focuses.
    /// Accordion windows overlap, so a click that changes window there cannot have been direct.
    public func suggestion(for focus: FocusSwitch, layout: WindowLayout, windowFrame: CGRect?) -> Suggestion? {
        guard let axis = layout.axis else { return nil }
        if case .tiles = layout {
            guard let windowFrame, let pointer = focus.pointer, !windowFrame.contains(pointer) else { return nil }
        }
        let directions: [FocusDirection] = axis == .horizontal ? [.left, .right] : [.up, .down]
        let pair = directions.compactMap { direction in
            index[.focus(direction)].map { (action: Action.focus(direction), binding: $0) }
        }
        guard let first = pair.first else { return nil }
        let companion = pair.dropFirst().first.map { Suggestion.Companion(action: $0.action, binding: $0.binding) }
        return Suggestion(action: first.action, binding: first.binding, companion: companion, trigger: .focusChange)
    }
}
