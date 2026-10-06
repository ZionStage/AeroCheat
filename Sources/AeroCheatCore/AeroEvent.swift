import CoreGraphics
import Foundation

/// One line of `aerospace subscribe` output, reduced to what active mode needs.
public enum AeroEvent: Equatable {
    case bindingTriggered(binding: String, mode: String)
    case focusChanged(windowId: Int, workspace: String)
    case focusedWorkspaceChanged(prev: String, workspace: String)
    case modeChanged(mode: String)

    /// Decodes one JSON line. Unknown events, unknown fields and malformed lines yield `nil`:
    /// the subscribe API is a beta feature and must not crash the app when it evolves.
    public static func parse(line: String) -> AeroEvent? {
        guard let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
              let kind = object["_event"] as? String else { return nil }
        switch kind {
        case "binding-triggered":
            guard let binding = object["binding"] as? String else { return nil }
            return .bindingTriggered(binding: binding, mode: object["mode"] as? String ?? "main")
        case "focus-changed":
            guard let workspace = object["workspace"] as? String else { return nil }
            return .focusChanged(windowId: object["windowId"] as? Int ?? 0, workspace: workspace)
        case "focused-workspace-changed":
            guard let prev = object["prevWorkspace"] as? String, let workspace = object["workspace"] as? String else { return nil }
            return .focusedWorkspaceChanged(prev: prev, workspace: workspace)
        case "mode-changed":
            guard let mode = object["mode"] as? String else { return nil }
            return .modeChanged(mode: mode)
        default:
            return nil
        }
    }
}

/// Splits a byte stream into complete lines, keeping a partial trailing line for the next chunk.
public struct LineBuffer {
    private var pending = Data()

    public init() {}

    public mutating func append(_ data: Data) -> [String] {
        pending.append(data)
        var lines: [String] = []
        while let newline = pending.firstIndex(of: 0x0A) {
            let line = String(decoding: pending[pending.startIndex..<newline], as: UTF8.self)
            pending.removeSubrange(pending.startIndex...newline)
            if !line.isEmpty { lines.append(line) }
        }
        return lines
    }
}

/// How long ago the user last clicked or typed (hardware events), and where the pointer was.
public struct InputRecency: Equatable {
    public var sinceLeftMouseDown: TimeInterval
    public var sinceLeftMouseUp: TimeInterval
    /// Seconds since the last key press, `.infinity` when unknown.
    public var sinceKeyDown: TimeInterval
    /// Seconds since the last modifier key change, `.infinity` when unknown.
    public var sinceFlagsChanged: TimeInterval
    /// Pointer position in global display coordinates, `nil` when unknown.
    public var pointer: CGPoint?

    public init(
        sinceLeftMouseDown: TimeInterval,
        sinceLeftMouseUp: TimeInterval,
        sinceKeyDown: TimeInterval = .infinity,
        sinceFlagsChanged: TimeInterval = .infinity,
        pointer: CGPoint? = nil
    ) {
        self.sinceLeftMouseDown = sinceLeftMouseDown
        self.sinceLeftMouseUp = sinceLeftMouseUp
        self.sinceKeyDown = sinceKeyDown
        self.sinceFlagsChanged = sinceFlagsChanged
        self.pointer = pointer
    }

    /// No click seen for a long time.
    public static let idle = InputRecency(sinceLeftMouseDown: .infinity, sinceLeftMouseUp: .infinity)

    public var sinceLastClick: TimeInterval { min(sinceLeftMouseDown, sinceLeftMouseUp) }

    /// A key or a modifier came after the last click: the click did not cause what followed (Cmd-Tab, a launcher).
    public var keyFollowedClick: Bool { min(sinceKeyDown, sinceFlagsChanged) < sinceLastClick }
}
