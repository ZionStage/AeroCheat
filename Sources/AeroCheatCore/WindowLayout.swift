import Foundation

public enum LayoutAxis: Equatable {
    case horizontal, vertical
}

/// The `%{window-layout}` of a window, as `aerospace list-windows` prints it.
public enum WindowLayout: Equatable {
    case tiles(LayoutAxis)
    case accordion(LayoutAxis)
    case floating
    case nativeFullscreen
    /// Anything else (hidden, minimized, popup, or a layout a newer AeroSpace invented).
    case other(String)

    public init(raw: String) {
        switch raw {
        case "h_tiles": self = .tiles(.horizontal)
        case "v_tiles": self = .tiles(.vertical)
        case "h_accordion": self = .accordion(.horizontal)
        case "v_accordion": self = .accordion(.vertical)
        case "floating": self = .floating
        case "macos_native_fullscreen": self = .nativeFullscreen
        default: self = .other(raw)
        }
    }

    /// The direction `focus` moves along, `nil` when it is not derivable from the layout.
    public var axis: LayoutAxis? {
        switch self {
        case .tiles(let axis), .accordion(let axis): return axis
        case .floating, .nativeFullscreen, .other: return nil
        }
    }
}

/// The read-only `aerospace list-windows` call used to learn a window's layout.
public enum WindowListQuery {
    public static let arguments = ["list-windows", "--all", "--format", "%{window-id} %{window-layout}"]

    /// The layout of window `id` in the output of `arguments`, `nil` when the window is not listed or the output is odd.
    public static func layout(ofWindow id: Int, in output: String) -> WindowLayout? {
        for line in output.split(whereSeparator: \.isNewline) {
            let fields = line.split(separator: " ", omittingEmptySubsequences: true)
            guard fields.count == 2, Int(fields[0]) == id else { continue }
            return WindowLayout(raw: String(fields[1]))
        }
        return nil
    }

    /// Whether window `id` appears in the output of `arguments`.
    public static func lists(window id: Int, in output: String) -> Bool {
        layout(ofWindow: id, in: output) != nil
    }
}
