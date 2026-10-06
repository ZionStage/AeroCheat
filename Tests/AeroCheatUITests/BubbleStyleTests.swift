import AeroCheatCore
import AeroCheatUI
import XCTest

final class BubbleStyleTests: XCTestCase {
    /// A fake 1440x900 screen with a 24 pt menu bar: the visible frame stops 24 pt short of the top.
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let visible = CGRect(x: 0, y: 0, width: 1440, height: 876)
    private let size = CGSize(width: 300, height: 56)

    func testDefaultsAreTheShippedValues() {
        let style = BubbleStyle()
        XCTAssertEqual(style.corner, .topRight)
        XCTAssertEqual(style.margins, CGSize(width: 16, height: 80))
        XCTAssertEqual(style.duration, 4)
        XCTAssertEqual(style.fadeOutDuration, 0.25)
        XCTAssertEqual(style.cornerRadius, 14)
        XCTAssertEqual(style.padding, CGSize(width: 16, height: 10))
    }

    func testDefaultOriginIsTheTopRightCornerWithMirroredMargins() {
        let origin = BubbleStyle().origin(for: size, in: visible)
        XCTAssertEqual(origin.x, 1440 - 300 - 16)
        XCTAssertEqual(origin.y, 876 - 56 - 80)
    }

    func testTopLeftOriginUsesTheMarginsFromTheVisibleFrame() {
        var style = BubbleStyle()
        style.corner = .topLeft
        let origin = style.origin(for: size, in: visible)
        XCTAssertEqual(origin.x, 16)
        XCTAssertEqual(origin.y, 876 - 56 - 80)
    }

    func testOriginFollowsTheVisibleFrameOffsetOfASecondaryScreen() {
        let frame = CGRect(x: -1920, y: 100, width: 1920, height: 1055)
        let origin = BubbleStyle().origin(for: size, in: frame)
        XCTAssertEqual(origin.x, -1920 + 1920 - 300 - 16)
        XCTAssertEqual(origin.y, 100 + 1055 - 56 - 80)
    }

    func testTopMarginClearsSketchyBar() {
        // SketchyBar sits about 74 pt below the top of the screen; the bubble's top edge must be lower still.
        let origin = BubbleStyle().origin(for: size, in: visible)
        let bubbleTopFromScreenTop = screen.maxY - (origin.y + size.height)
        XCTAssertGreaterThanOrEqual(bubbleTopFromScreenTop, 74)
    }

    func testBubbleStaysInsideTheVisibleFrame() {
        for corner in [BubbleStyle.Corner.topLeft, .topRight] {
            var style = BubbleStyle()
            style.corner = corner
            let origin = style.origin(for: size, in: visible)
            XCTAssertTrue(visible.contains(CGRect(origin: origin, size: size)), "\(corner)")
        }
    }

    func testCustomMarginsMoveTheBubble() {
        var style = BubbleStyle()
        style.margins = CGSize(width: 40, height: 10)
        XCTAssertEqual(style.origin(for: size, in: visible), CGPoint(x: 1440 - 300 - 40, y: 876 - 56 - 10))
        style.corner = .topLeft
        XCTAssertEqual(style.origin(for: size, in: visible), CGPoint(x: 40, y: 876 - 56 - 10))
    }
}
