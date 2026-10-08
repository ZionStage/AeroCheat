import CoreGraphics
import Foundation

/// A window the window server lists as on screen. Only what the hit test needs.
public struct ScreenWindow: Equatable {
    /// Bundle identifier of the owning process, `nil` when unknown. The owner *name* is localised, so it is not used.
    public let ownerBundleID: String?
    /// Global display coordinates, the same space as the pointer position.
    public let bounds: CGRect
    /// Window level (`kCGWindowLayer`).
    public let layer: Int

    public init(ownerBundleID: String?, bounds: CGRect, layer: Int = 0) {
        self.ownerBundleID = ownerBundleID
        self.bounds = bounds
        self.layer = layer
    }
}

/// A part of the screen where a click is not a mouse habit to correct, recognised from the windows that draw it.
public enum ScreenZone: Equatable {
    /// A notification banner, or the Notification Center panel.
    case notifications
    /// The Dock, on any display.
    case dock

    /// Notification Center draws both the banners and the panel, in separate windows from its own process.
    public static let notificationCenterBundleID = "com.apple.notificationcenterui"
    /// The Dock process also draws Mission Control and Launchpad, in display-sized windows.
    public static let dockBundleID = "com.apple.dock"
    /// Wider windows are not a banner or the panel (about 350 and 400 points): the process also keeps a
    /// display-sized helper window that is not on screen when no notification is shown, and would swallow every click.
    public static let maxNotificationWidth: CGFloat = 700
    /// The Dock bar is thinner than this even with magnification; Mission Control and Launchpad are not.
    public static let maxDockThickness: CGFloat = 400
    static let dockLayer = Int(CGWindowLevelForKey(.dockWindow))

    public func contains(_ window: ScreenWindow) -> Bool {
        guard window.bounds.width > 0, window.bounds.height > 0 else { return false }
        switch self {
        case .notifications:
            return window.ownerBundleID == Self.notificationCenterBundleID && window.bounds.width <= Self.maxNotificationWidth
        case .dock:
            return window.ownerBundleID == Self.dockBundleID && window.layer == Self.dockLayer
                && min(window.bounds.width, window.bounds.height) <= Self.maxDockThickness
        }
    }
}

/// Tells whether the pointer is over a zone: a macOS notification, or the Dock.
///
/// A banner can be gone by the time AeroCheat looks (a click on it dismisses it), and a hidden Dock can slide away,
/// so the bounds of the zone's windows seen on screen are remembered for `memory` seconds and the pointer is tested
/// against those. Timestamps are monotonic seconds supplied by the caller, so the type is deterministic in tests.
public struct ScreenZoneHitTest {
    private static let maxSightings = 16

    public let zone: ScreenZone
    public var memory: TimeInterval

    private var sightings: [(bounds: CGRect, time: TimeInterval)] = []

    public init(zone: ScreenZone, memory: TimeInterval = 2) {
        self.zone = zone
        self.memory = memory
    }

    /// Records the zone's windows among the windows now on screen and forgets the ones seen too long ago.
    public mutating func observe(_ windows: [ScreenWindow], at time: TimeInterval) {
        sightings.removeAll { time - $0.time > memory }
        for window in windows where zone.contains(window) {
            if let index = sightings.firstIndex(where: { $0.bounds == window.bounds }) {
                sightings[index].time = time
            } else {
                sightings.append((window.bounds, time))
            }
        }
        if sightings.count > Self.maxSightings { sightings.removeFirst(sightings.count - Self.maxSightings) }
    }

    /// Whether `pointer` lies inside one of the zone's windows seen at most `memory` seconds before `time`.
    public func isOver(_ pointer: CGPoint?, at time: TimeInterval) -> Bool {
        guard let pointer else { return false }
        return sightings.contains { time - $0.time <= memory && $0.bounds.contains(pointer) }
    }

    public mutating func reset() {
        sightings = []
    }
}
