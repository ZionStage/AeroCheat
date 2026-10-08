import AeroCheatCore
import AppKit
import CoreGraphics

/// Lists the windows on screen, read-only. `CGWindowListCopyWindowInfo` gives the owner, bounds, level and on-screen
/// state of other apps' windows without any macOS permission (window titles and content would need one, and are not
/// read). Main queue only.
enum ScreenWindowProbe {
    /// With no keyboard or mouse input for this long, the queries thin out to one per `idleInterval`: a banner stays up
    /// for several seconds and the Dock does not move, so they are still seen before the user's first click, at a
    /// negligible cost.
    private static let idleLimit: TimeInterval = 5
    private static let idleInterval: TimeInterval = 2
    private static var lastIdleQuery: TimeInterval = -.infinity
    /// Bundle identifier per process id; an empty string stands for "none". Owner names are localised, so the
    /// bundle identifier is what identifies Notification Center and the Dock.
    private static var bundleIDs: [Int: String] = [:]

    static func windows() -> [ScreenWindow] {
        guard let anyInput = CGEventType(rawValue: UInt32.max) else { return [] }
        if CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: anyInput) >= idleLimit {
            let now = ProcessInfo.processInfo.systemUptime
            guard now - lastIdleQuery >= idleInterval else { return [] }
            lastIdleQuery = now
        }
        guard let list = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]]
        else { return [] }
        return list.compactMap { info in
            guard let pid = info[kCGWindowOwnerPID as String] as? Int,
                  let boundsInfo = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsInfo)
            else { return nil }
            let id = bundleID(ofProcess: pid)
            return ScreenWindow(ownerBundleID: id.isEmpty ? nil : id, bounds: bounds, layer: info[kCGWindowLayer as String] as? Int ?? 0)
        }
    }

    /// The application that owns window `id` (an AeroSpace window id is a `CGWindowID`), `nil` when it is not listed.
    static func app(ofWindow id: Int) -> AppIdentity? {
        guard let info = (CGWindowListCopyWindowInfo([.optionIncludingWindow], CGWindowID(id)) as? [[String: Any]])?.first,
              let pid = info[kCGWindowOwnerPID as String] as? Int
        else { return nil }
        let app = NSRunningApplication(processIdentifier: pid_t(pid))
        return AppIdentity(
            name: app?.localizedName ?? info[kCGWindowOwnerName as String] as? String,
            bundleID: app?.bundleIdentifier
        )
    }

    private static func bundleID(ofProcess pid: Int) -> String {
        if let known = bundleIDs[pid] { return known }
        if bundleIDs.count > 256 { bundleIDs = [:] }
        let id = NSRunningApplication(processIdentifier: pid_t(pid))?.bundleIdentifier ?? ""
        bundleIDs[pid] = id
        return id
    }
}
