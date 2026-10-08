import XCTest
@testable import AeroCheatCore

final class ScreenZoneHitTestTests: XCTestCase {
    private let banner = CGRect(x: 1140, y: 40, width: 360, height: 80)
    private let inside = CGPoint(x: 1300, y: 80)
    private let outside = CGPoint(x: 400, y: 600)

    private func window(_ bounds: CGRect, owner: String? = ScreenZone.notificationCenterBundleID) -> ScreenWindow {
        ScreenWindow(ownerBundleID: owner, bounds: bounds)
    }

    func testClickInsideABannerIsOverANotification() {
        var test = ScreenZoneHitTest(zone: .notifications)
        test.observe([window(banner)], at: 10)
        XCTAssertTrue(test.isOver(inside, at: 10.2))
        XCTAssertFalse(test.isOver(outside, at: 10.2))
    }

    func testBannerSeenTooLongAgoIsForgotten() {
        var test = ScreenZoneHitTest(zone: .notifications)
        test.observe([window(banner)], at: 10)
        XCTAssertTrue(test.isOver(inside, at: 11.9), "the banner is gone, but was there a moment ago")
        XCTAssertFalse(test.isOver(inside, at: 12.1))
    }

    func testNoBannerAndOtherWindowsChangeNothing() {
        var test = ScreenZoneHitTest(zone: .notifications)
        test.observe([], at: 10)
        test.observe([window(banner, owner: "com.apple.dock"), window(banner, owner: nil)], at: 10.5)
        XCTAssertFalse(test.isOver(inside, at: 10.6))
        XCTAssertFalse(test.isOver(nil, at: 10.6))
    }

    func testDisplaySizedHelperWindowDoesNotCount() {
        var test = ScreenZoneHitTest(zone: .notifications)
        test.observe([window(CGRect(x: 0, y: 0, width: 1512, height: 982))], at: 10)
        XCTAssertFalse(test.isOver(outside, at: 10.1))
    }

    func testClickOnABannerIsIgnoredForBothKindsOfSuggestion() {
        let onBanner = InputRecency(sinceLeftMouseDown: 0.2, sinceLeftMouseUp: 0.15, onNotification: true)
        var classifier = BurstClassifier()
        _ = classifier.ingest(.focusChanged(windowId: 1, workspace: "1"), at: 0, input: .idle)
        _ = classifier.flush()
        _ = classifier.ingest(.focusedWorkspaceChanged(prev: "1", workspace: "3"), at: 5, input: onBanner)
        XCTAssertEqual(classifier.flush(), .ignored(.notificationClick))
        _ = classifier.ingest(.focusChanged(windowId: 2, workspace: "3"), at: 6, input: .idle)
        _ = classifier.flush()
        _ = classifier.ingest(.focusChanged(windowId: 3, workspace: "3"), at: 10, input: onBanner)
        XCTAssertEqual(classifier.flush(), .ignored(.notificationClick))
    }

    func testDockBarCountsButMissionControlDoesNot() {
        let dockLayer = Int(CGWindowLevelForKey(.dockWindow))
        let bar = ScreenWindow(ownerBundleID: ScreenZone.dockBundleID, bounds: CGRect(x: 300, y: 900, width: 900, height: 80), layer: dockLayer)
        let missionControl = ScreenWindow(ownerBundleID: ScreenZone.dockBundleID, bounds: CGRect(x: 0, y: 0, width: 1512, height: 982), layer: dockLayer)
        var test = ScreenZoneHitTest(zone: .dock)
        test.observe([bar, missionControl], at: 10)
        XCTAssertTrue(test.isOver(CGPoint(x: 700, y: 940), at: 10.1))
        XCTAssertFalse(test.isOver(CGPoint(x: 700, y: 400), at: 10.1))
    }

    func testClickInTheDockIsIgnored() {
        let inDock = InputRecency(sinceLeftMouseDown: 0.2, sinceLeftMouseUp: 0.15, onDock: true)
        var classifier = BurstClassifier()
        _ = classifier.ingest(.focusedWorkspaceChanged(prev: "1", workspace: "3"), at: 5, input: inDock)
        XCTAssertEqual(classifier.flush(), .ignored(.dockClick))
    }
}
