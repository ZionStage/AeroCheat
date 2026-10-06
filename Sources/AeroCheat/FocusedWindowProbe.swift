import AeroCheatCore
import CoreGraphics
import Foundation

/// What the focus suggestion needs to know about the window a click landed on.
struct FocusedWindowInfo {
    let layout: WindowLayout
    /// Frame in global display coordinates, the same space as the pointer.
    let frame: CGRect?
}

/// Reads a window's layout with the read-only `aerospace list-windows` and its frame from the window server.
/// Window bounds need no macOS permission (only window names do); AeroSpace window ids are `CGWindowID`s.
enum FocusedWindowProbe {
    private static let timeout: TimeInterval = 2

    /// Blocking: call it off the main queue. `nil` when the window is not listed, when the window focus came from
    /// is gone (it was closed and focus fell to a neighbour), or when AeroSpace cannot be reached.
    static func info(ofWindow id: Int, previousWindow: Int, binary: String) -> FocusedWindowInfo? {
        guard let output = run(binary), WindowListQuery.lists(window: previousWindow, in: output),
              let layout = WindowListQuery.layout(ofWindow: id, in: output) else { return nil }
        // Only tiles compare the pointer with the frame.
        guard case .tiles = layout else { return FocusedWindowInfo(layout: layout, frame: nil) }
        return FocusedWindowInfo(layout: layout, frame: frame(ofWindow: id))
    }

    private static func run(_ binary: String) -> String? {
        let child = Process()
        child.executableURL = URL(fileURLWithPath: binary)
        child.arguments = WindowListQuery.arguments
        let out = Pipe()
        child.standardOutput = out
        child.standardError = FileHandle.nullDevice
        child.standardInput = FileHandle.nullDevice
        do { try child.run() } catch { return nil }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
            if child.isRunning { child.terminate() }
        }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        child.waitUntilExit()
        guard child.terminationStatus == 0 else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    private static func frame(ofWindow id: Int) -> CGRect? {
        guard let windows = CGWindowListCopyWindowInfo([.optionIncludingWindow], CGWindowID(id)) as? [[String: Any]],
              let bounds = windows.first?[kCGWindowBounds as String] as? NSDictionary else { return nil }
        return CGRect(dictionaryRepresentation: bounds)
    }
}
