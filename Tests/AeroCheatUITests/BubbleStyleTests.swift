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
        XCTAssertEqual(style.anchor, .topRight)
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
        style.anchor = .topLeft
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
        for anchor in BubbleAnchor.allCases {
            var style = BubbleStyle()
            style.anchor = anchor
            let origin = style.origin(for: size, in: visible)
            XCTAssertTrue(visible.contains(CGRect(origin: origin, size: size)), "\(anchor)")
        }
    }

    func testCustomMarginsMoveTheBubble() {
        var style = BubbleStyle()
        style.margins = CGSize(width: 40, height: 10)
        XCTAssertEqual(style.origin(for: size, in: visible), CGPoint(x: 1440 - 300 - 40, y: 876 - 56 - 10))
        style.anchor = .topLeft
        XCTAssertEqual(style.origin(for: size, in: visible), CGPoint(x: 40, y: 876 - 56 - 10))
    }

    // MARK: The nine anchors

    func testEveryAnchorAgainstTheFakeScreen() {
        let left: CGFloat = 20, top: CGFloat = 30
        let expected: [BubbleAnchor: CGPoint] = [
            .topLeft: CGPoint(x: left, y: 876 - 56 - top),
            .topCenter: CGPoint(x: (1440 - 300) / 2, y: 876 - 56 - top),
            .topRight: CGPoint(x: 1440 - 300 - left, y: 876 - 56 - top),
            .middleLeft: CGPoint(x: left, y: (876 - 56) / 2),
            .center: CGPoint(x: (1440 - 300) / 2, y: (876 - 56) / 2),
            .middleRight: CGPoint(x: 1440 - 300 - left, y: (876 - 56) / 2),
            .bottomLeft: CGPoint(x: left, y: top),
            .bottomCenter: CGPoint(x: (1440 - 300) / 2, y: top),
            .bottomRight: CGPoint(x: 1440 - 300 - left, y: top),
        ]
        XCTAssertEqual(Set(expected.keys), Set(BubbleAnchor.allCases))
        for (anchor, point) in expected {
            var style = BubbleStyle()
            style.anchor = anchor
            style.margins = CGSize(width: left, height: top)
            XCTAssertEqual(style.origin(for: size, in: visible), point, "\(anchor)")
        }
    }

    func testCentredAxesIgnoreTheMargins() {
        var style = BubbleStyle()
        style.anchor = .center
        let reference = style.origin(for: size, in: visible)
        style.margins = CGSize(width: 300, height: 300)
        XCTAssertEqual(style.origin(for: size, in: visible), reference)
    }

    func testAnchorsFollowTheVisibleFrameOffsetOfASecondaryScreen() {
        let frame = CGRect(x: -1920, y: 100, width: 1920, height: 1055)
        var style = BubbleStyle()
        style.anchor = .bottomLeft
        XCTAssertEqual(style.origin(for: size, in: frame), CGPoint(x: -1920 + 16, y: 100 + 80))
        style.anchor = .center
        XCTAssertEqual(style.origin(for: size, in: frame), CGPoint(x: -1110, y: 599.5))
    }

    func testHugeMarginsKeepTheBubbleInsideTheFrame() {
        for anchor in BubbleAnchor.allCases {
            var style = BubbleStyle()
            style.anchor = anchor
            style.margins = CGSize(width: 5000, height: 5000)
            let origin = style.origin(for: size, in: visible)
            XCTAssertTrue(visible.contains(CGRect(origin: origin, size: size)), "\(anchor)")
        }
    }

    // MARK: Mapping from the settings

    func testDefaultSettingsGiveTheShippedStyle() {
        let mapped = BubbleStyle(settings: DisplaySettings())
        let shipped = BubbleStyle()
        XCTAssertEqual(mapped.anchor, shipped.anchor)
        XCTAssertEqual(mapped.margins, shipped.margins)
        XCTAssertEqual(mapped.duration, shipped.duration)
        XCTAssertEqual(mapped.opacity, shipped.opacity)
        XCTAssertEqual(mapped.cornerRadius, shipped.cornerRadius)
        XCTAssertEqual(mapped.padding, shipped.padding)
        XCTAssertEqual(mapped.contentSpacing, shipped.contentSpacing)
        XCTAssertEqual(mapped.keycapSpacing, shipped.keycapSpacing)
        XCTAssertEqual(mapped.keycapCornerRadius, shipped.keycapCornerRadius)
        XCTAssertEqual(mapped.keycapPadding, shipped.keycapPadding)
        XCTAssertEqual([mapped.keyFontSize, mapped.titleFontSize, mapped.hintFontSize], [15, 12, 10])
    }

    func testSettingsMapToPositionDurationOpacityAndSize() {
        var settings = DisplaySettings()
        settings.anchor = .bottomCenter
        settings.horizontalMargin = 30
        settings.verticalMargin = 12
        settings.duration = 9
        settings.opacity = 0.6
        settings.scale = 1.5
        let style = BubbleStyle(settings: settings)
        XCTAssertEqual(style.anchor, .bottomCenter)
        XCTAssertEqual(style.margins, CGSize(width: 30, height: 12))
        XCTAssertEqual(style.duration, 9)
        XCTAssertEqual(style.opacity, 0.6)
        XCTAssertEqual(style.padding, CGSize(width: 24, height: 15))
        XCTAssertEqual(style.keyFontSize, 22.5)
        XCTAssertEqual(style.titleFontSize, 18)
        XCTAssertEqual(style.hintFontSize, 15)
    }

    func testOutOfRangeSettingsAreClampedBeforeMapping() {
        var settings = DisplaySettings()
        settings.scale = 50
        settings.duration = -3
        let style = BubbleStyle(settings: settings)
        XCTAssertEqual(style.duration, DisplaySettings.durationRange.lowerBound)
        XCTAssertEqual(style.padding.width, 16 * CGFloat(DisplaySettings.scaleRange.upperBound))
    }

    func testColourRoundTripsThroughSwiftUI() throws {
        let color = SettingsColor(red: 0.2, green: 0.4, blue: 0.6)
        let back = try XCTUnwrap(SettingsColor(color.color))
        XCTAssertEqual(back.red, 0.2, accuracy: 0.01)
        XCTAssertEqual(back.green, 0.4, accuracy: 0.01)
        XCTAssertEqual(back.blue, 0.6, accuracy: 0.01)
    }
}
