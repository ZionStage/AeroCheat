import AeroCheatCore
import AeroCheatUI
import AppKit
import XCTest

/// Offscreen rendering of the bubble. It asserts what is deterministic: size bounds, that something is
/// painted, and that icons versus text fallback change the picture. No golden images, no pixel equality.
@MainActor
final class BubbleRenderTests: XCTestCase {
    private let allSymbols: (String) -> Bool = { _ in true }
    private let noSymbols: (String) -> Bool = { _ in false }

    func testDefaultBubbleSizeStaysWithinBounds() throws {
        let content = BubbleContent(suggestion: try BubbleRender.suggestion("ctrl-alt-3"), symbolAvailable: allSymbols)
        let render = try BubbleRender.render(content)
        XCTAssertGreaterThanOrEqual(render.size.width, 150)
        XCTAssertLessThanOrEqual(render.size.width, 480)
        XCTAssertGreaterThanOrEqual(render.size.height, 36)
        XCTAssertLessThanOrEqual(render.size.height, 90)
    }

    func testHintMakesTheBubbleTallerThanWithoutOne() throws {
        let plain = try BubbleRender.render(BubbleContent(suggestion: try BubbleRender.suggestion("ctrl-alt-3"), symbolAvailable: allSymbols))
        let hinted = try BubbleRender.render(BubbleContent(
            suggestion: try BubbleRender.suggestion("ctrl-alt-3", backAndForth: "ctrl-alt-tab"),
            symbolAvailable: allSymbols
        ))
        XCTAssertGreaterThan(hinted.size.height, plain.size.height)
        XCTAssertLessThanOrEqual(hinted.size.height, 120)
        XCTAssertLessThanOrEqual(hinted.size.width, 480)
    }

    func testBitmapMatchesTheViewSizeAndIsPainted() throws {
        let content = BubbleContent(suggestion: try BubbleRender.suggestion("ctrl-alt-3"), symbolAvailable: allSymbols)
        let render = try BubbleRender.render(content)
        XCTAssertGreaterThanOrEqual(render.bitmap.pixelsWide, Int(render.size.width))
        XCTAssertGreaterThanOrEqual(render.bitmap.pixelsHigh, Int(render.size.height))
        XCTAssertGreaterThan(render.paintedPixelCount, 100, "the bubble rendered blank")
        XCTAssertGreaterThan(render.inkPixelCount, 20, "no text or icon ink found")
    }

    func testIconsAndTextFallbackRenderDifferently() throws {
        let suggestion = try BubbleRender.suggestion("ctrl-alt-3")
        let icons = try BubbleRender.render(BubbleContent(suggestion: suggestion, symbolAvailable: allSymbols))
        let glyphs = try BubbleRender.render(BubbleContent(suggestion: suggestion, symbolAvailable: noSymbols))
        XCTAssertNotEqual(
            icons.bitmap.representation(using: .png, properties: [:]),
            glyphs.bitmap.representation(using: .png, properties: [:]),
            "symbol icons and glyph fallback must not draw the same picture"
        )
        // Both still draw something readable.
        XCTAssertGreaterThan(glyphs.inkPixelCount, 20)
    }

    func testNarrowerStyleProducesSmallerBubble() throws {
        let content = BubbleContent(suggestion: try BubbleRender.suggestion("ctrl-alt-3"), symbolAvailable: allSymbols)
        var compact = BubbleStyle()
        compact.padding = CGSize(width: 4, height: 2)
        let normal = try BubbleRender.render(content)
        let small = try BubbleRender.render(content, style: compact)
        XCTAssertLessThan(small.size.width, normal.size.width)
        XCTAssertLessThan(small.size.height, normal.size.height)
    }
}
