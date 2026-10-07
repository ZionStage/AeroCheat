import CoreGraphics
import Foundation

/// A window the window server lists as on screen. Only what the hit test needs.
public struct ScreenWindow: Equatable {
    /// Bundle identifier of the owning process, `nil` when unknown. The owner *name* is localised, so it is not used.
    public let ownerBundleID: String?
    /// Global display coordinates, the same space as the pointer position.
    public let bounds: CGRect

    public init(ownerBundleID: String?, bounds: CGRect) {
        self.ownerBundleID = ownerBundleID
        self.bounds = bounds
    }
}

/// Tells whether the pointer is over a macOS notification: a banner, or the Notification Center panel.
///
/// A banner can be gone by the time AeroCheat looks (a click on it dismisses it), so the bounds of the notification
/// windows seen on screen are remembered for `memory` seconds and the pointer is tested against those.
/// Timestamps are monotonic seconds supplied by the caller, so the type is deterministic in tests.
public struct NotificationHitTest {
    /// Notification Center draws both the banners and the panel, in separate windows from its own process.
    public static let notificationCenterBundleID = "com.apple.notificationcenterui"
    /// Wider windows are not a banner or the panel (about 350 and 400 points): the process also keeps a
    /// display-sized helper window that is not on screen when no notification is shown, and would swallow every click.
    public static let maxWidth: CGFloat = 700
    private static let maxSightings = 16

    public var memory: TimeInterval

    private var sightings: [(bounds: CGRect, time: TimeInterval)] = []

    public init(memory: TimeInterval = 2) {
        self.memory = memory
    }

    /// Records the notification windows among the windows now on screen and forgets the ones seen too long ago.
    public mutating func observe(_ windows: [ScreenWindow], at time: TimeInterval) {
        sightings.removeAll { time - $0.time > memory }
        for window in windows where Self.isNotificationWindow(window) {
            if let index = sightings.firstIndex(where: { $0.bounds == window.bounds }) {
                sightings[index].time = time
            } else {
                sightings.append((window.bounds, time))
            }
        }
        if sightings.count > Self.maxSightings { sightings.removeFirst(sightings.count - Self.maxSightings) }
    }

    /// Whether `pointer` lies inside a notification window seen at most `memory` seconds before `time`.
    public func isOverNotification(_ pointer: CGPoint?, at time: TimeInterval) -> Bool {
        guard let pointer else { return false }
        return sightings.contains { time - $0.time <= memory && $0.bounds.contains(pointer) }
    }

    public mutating func reset() {
        sightings = []
    }

    private static func isNotificationWindow(_ window: ScreenWindow) -> Bool {
        window.ownerBundleID == notificationCenterBundleID
            && window.bounds.width > 0 && window.bounds.height > 0
            && window.bounds.width <= maxWidth
    }
}
