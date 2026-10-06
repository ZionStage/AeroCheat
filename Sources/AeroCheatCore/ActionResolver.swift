import Foundation

/// A canonical AeroSpace action, enough to tell which binding performs it.
public enum Action: Hashable, CustomStringConvertible {
    case workspace(String)
    case workspaceBackAndForth
    case other(String)

    /// Canonical form of one command: `--flags` are dropped, `workspace next|prev` stays `other`.
    public init(command: String) {
        let tokens = command.split(separator: " ").map(String.init)
        guard let head = tokens.first else { self = .other(command); return }
        let args = tokens.dropFirst().filter { !$0.hasPrefix("--") }
        switch head {
        case "workspace" where args.count == 1 && !["next", "prev"].contains(args[0]):
            self = .workspace(args[0])
        case "workspace-back-and-forth" where args.isEmpty:
            self = .workspaceBackAndForth
        default:
            self = .other(command)
        }
    }

    public var description: String {
        switch self {
        case .workspace(let name): return "workspace \(name)"
        case .workspaceBackAndForth: return "workspace-back-and-forth"
        case .other(let command): return command
        }
    }
}

/// What to tell the user after a mouse-driven switch.
public struct Suggestion: Equatable {
    public let action: Action
    public let binding: Binding
    /// Binding that toggles back to the previous workspace, when relevant and configured.
    public let backAndForth: Binding?

    /// Identity used by cooldowns and learning.
    public var key: String { binding.combo.canonical }
    public var keys: String { binding.combo.display }
    public var title: String {
        if case .workspace(let name) = action { return "switch to workspace \(name)" }
        return action.description
    }
    public var hint: String? { backAndForth.map { "or \($0.combo.display) to toggle back" } }

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
    public func suggestion(for mouseSwitch: MouseSwitch) -> Suggestion? {
        let action = Action.workspace(mouseSwitch.to)
        guard let binding = index[action] else { return nil }
        let back = mouseSwitch.returnsToPrevious ? index[.workspaceBackAndForth] : nil
        return Suggestion(action: action, binding: binding, backAndForth: back)
    }
}
