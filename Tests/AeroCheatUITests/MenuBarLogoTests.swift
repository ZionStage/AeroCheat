import AeroCheatUI
import AppKit
import XCTest

final class MenuBarLogoTests: XCTestCase {
    func testEmbeddedGlyphIsAnEighteenPointTemplateImage() throws {
        let image = try XCTUnwrap(MenuBarLogo.makeImage())
        XCTAssertEqual(image.size, NSSize(width: 18, height: 18))
        XCTAssertTrue(image.isTemplate)
        let pixelWidths = image.representations.map(\.pixelsWide).sorted()
        XCTAssertEqual(pixelWidths, [18, 36])
    }
}
