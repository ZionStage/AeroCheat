import AeroCheatCore
import AeroCheatUI
import AppKit
import SwiftUI
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

// MARK: Rendering from the settings

@MainActor
final class BubbleSettingsRenderTests: XCTestCase {
    private func render(_ settings: DisplaySettings, binding: String = "ctrl-alt-3") throws -> BubbleRender.Result {
        let content = BubbleContent(suggestion: try BubbleRender.suggestion(binding), settings: settings)
        return try BubbleRender.render(content, style: BubbleStyle(settings: settings))
    }

    private func png(_ result: BubbleRender.Result) -> Data? {
        result.bitmap.representation(using: .png, properties: [:])
    }

    func testDefaultSettingsRenderTheShippedBubble() throws {
        let shipped = try BubbleRender.render(BubbleContent(suggestion: try BubbleRender.suggestion("ctrl-alt-3")))
        let fromSettings = try render(DisplaySettings())
        XCTAssertEqual(fromSettings.size, shipped.size)
    }

    func testIconsVersusTextForModifiers() throws {
        var settings = DisplaySettings()
        let icons = try render(settings)
        settings.iconsForModifiers = false
        let text = try render(settings)
        let content = BubbleContent(suggestion: try BubbleRender.suggestion("ctrl-alt-3"), settings: settings)
        XCTAssertEqual(content.caps, [.text("⌃"), .text("⌥"), .text("3")])
        XCTAssertNotEqual(png(icons), png(text))
        XCTAssertGreaterThan(text.inkPixelCount, 20)
    }

    func testSizeScalesTheBubbleAndStaysWithinBounds() throws {
        var settings = DisplaySettings()
        let normal = try render(settings)
        settings.scale = DisplaySettings.scaleRange.lowerBound
        let small = try render(settings)
        settings.scale = DisplaySettings.scaleRange.upperBound
        let large = try render(settings)
        XCTAssertLessThan(small.size.width, normal.size.width)
        XCTAssertLessThan(small.size.height, normal.size.height)
        XCTAssertGreaterThan(large.size.width, normal.size.width)
        XCTAssertGreaterThan(large.size.height, normal.size.height)
        // The smallest and the largest stay readable and on a screen.
        XCTAssertGreaterThanOrEqual(small.size.width, 110)
        XCTAssertGreaterThanOrEqual(small.size.height, 28)
        XCTAssertLessThanOrEqual(large.size.width, 480 * CGFloat(DisplaySettings.scaleRange.upperBound))
        XCTAssertLessThanOrEqual(large.size.height, 90 * CGFloat(DisplaySettings.scaleRange.upperBound))
        XCTAssertGreaterThan(large.inkPixelCount, normal.inkPixelCount)
    }

    func testCustomBackgroundColourIsPainted() throws {
        var settings = DisplaySettings()
        settings.backgroundColor = SettingsColor(red: 1, green: 0, blue: 0)
        let result = try render(settings)
        var red = 0
        for y in 0..<result.bitmap.pixelsHigh {
            for x in 0..<result.bitmap.pixelsWide {
                guard let c = result.bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB), c.alphaComponent > 0.9 else { continue }
                if c.redComponent > 0.9, c.greenComponent < 0.15, c.blueComponent < 0.15 { red += 1 }
            }
        }
        XCTAssertGreaterThan(red, Int(result.size.width * result.size.height) / 3, "the background is not the picked colour")
    }

    func testCustomTextColourChangesThePicture() throws {
        var settings = DisplaySettings()
        let normal = try render(settings)
        settings.textColor = SettingsColor(red: 1, green: 0, blue: 1)
        settings.iconTint = SettingsColor(red: 0, green: 1, blue: 1)
        XCTAssertNotEqual(png(try render(settings)), png(normal))
    }

    func testOpacityMakesTheBubbleMoreTransparent() throws {
        func maxAlpha(_ result: BubbleRender.Result) -> CGFloat {
            var best: CGFloat = 0
            for y in 0..<result.bitmap.pixelsHigh {
                for x in 0..<result.bitmap.pixelsWide { best = max(best, result.bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) }
            }
            return best
        }
        var settings = DisplaySettings()
        settings.backgroundColor = SettingsColor(red: 0, green: 0, blue: 0)
        let opaque = try render(settings)
        settings.opacity = DisplaySettings.opacityRange.lowerBound
        let faint = try render(settings)
        XCTAssertGreaterThan(maxAlpha(opaque), 0.95)
        XCTAssertLessThan(maxAlpha(faint), 0.6)
    }

    func testEveryAnchorGivesAnOriginInsideAFakeScreenForARenderedBubble() throws {
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 876)
        let size = try render(DisplaySettings()).size
        for anchor in BubbleAnchor.allCases {
            var settings = DisplaySettings()
            settings.anchor = anchor
            let origin = BubbleStyle(settings: settings).origin(for: size, in: visible)
            XCTAssertTrue(visible.contains(CGRect(origin: origin, size: size)), "\(anchor)")
        }
    }

    func testSettingsViewRendersSomething() throws {
        let model = DisplaySettingsModel(inMemory: DisplaySettings())
        let hosting = NSHostingView(rootView: SettingsView(model: model, onPreview: {}))
        hosting.appearance = NSAppearance(named: .aqua)
        hosting.frame = NSRect(x: 0, y: 0, width: 480, height: 640)
        hosting.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        if let directory = ProcessInfo.processInfo.environment["AEROCHEAT_SNAPSHOT_DIR"],
           let data = bitmap.representation(using: .png, properties: [:]) {
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            try data.write(to: URL(fileURLWithPath: directory).appendingPathComponent("settings-view.png"))
        }
        var painted = 0
        for y in stride(from: 0, to: bitmap.pixelsHigh, by: 2) {
            for x in stride(from: 0, to: bitmap.pixelsWide, by: 2) where (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.01 { painted += 1 }
        }
        XCTAssertGreaterThan(painted, 1000, "the settings view rendered blank")
    }
}
