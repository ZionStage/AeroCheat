import XCTest
@testable import AeroCheatCore

final class NotificationHitTestTests: XCTestCase {
    private let banner = CGRect(x: 1140, y: 40, width: 360, height: 80)
    private let inside = CGPoint(x: 1300, y: 80)
    private let outside = CGPoint(x: 400, y: 600)

    private func window(_ bounds: CGRect, owner: String? = NotificationHitTest.notificationCenterBundleID) -> ScreenWindow {
        ScreenWindow(ownerBundleID: owner, bounds: bounds)
    }

    func testClickInsideABannerIsOverANotification() {
        var test = NotificationHitTest()
        test.observe([window(banner)], at: 10)
        XCTAssertTrue(test.isOverNotification(inside, at: 10.2))
        XCTAssertFalse(test.isOverNotification(outside, at: 10.2))
    }

    func testBannerSeenTooLongAgoIsForgotten() {
        var test = NotificationHitTest()
        test.observe([window(banner)], at: 10)
        XCTAssertTrue(test.isOverNotification(inside, at: 11.9), "the banner is gone, but was there a moment ago")
        XCTAssertFalse(test.isOverNotification(inside, at: 12.1))
    }

    func testNoBannerAndOtherWindowsChangeNothing() {
        var test = NotificationHitTest()
        test.observe([], at: 10)
        test.observe([window(banner, owner: "com.apple.dock"), window(banner, owner: nil)], at: 10.5)
        XCTAssertFalse(test.isOverNotification(inside, at: 10.6))
        XCTAssertFalse(test.isOverNotification(nil, at: 10.6))
    }

    func testDisplaySizedHelperWindowDoesNotCount() {
        var test = NotificationHitTest()
        test.observe([window(CGRect(x: 0, y: 0, width: 1512, height: 982))], at: 10)
        XCTAssertFalse(test.isOverNotification(outside, at: 10.1))
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
}
