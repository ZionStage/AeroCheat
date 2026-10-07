import AeroCheatCore
import AeroCheatUI
import XCTest

@MainActor
final class BubbleContentTests: XCTestCase {
    func testModifiersRenderAsIconsAndTheKeyAsText() throws {
        let content = BubbleContent(suggestion: try BubbleRender.suggestion("ctrl-alt-3"), symbolAvailable: { _ in true })
        XCTAssertEqual(content.caps, [.icon("control"), .icon("option"), .text("3")])
        XCTAssertEqual(content.title, "switch to workspace 3")
        XCTAssertNil(content.hint)
    }

    func testFallsBackToGlyphTextWhenASymbolIsUnavailable() throws {
        let content = BubbleContent(suggestion: try BubbleRender.suggestion("ctrl-alt-3"), symbolAvailable: { $0 != "option" })
        XCTAssertEqual(content.caps, [.icon("control"), .text("⌥"), .text("3")])
        let none = BubbleContent(suggestion: try BubbleRender.suggestion("ctrl-alt-3"), symbolAvailable: { _ in false })
        XCTAssertEqual(none.caps, [.text("⌃"), .text("⌥"), .text("3")])
    }

    func testTheSystemHasTheModifierSymbols() {
        for name in ["control", "option", "shift", "command"] {
            XCTAssertTrue(BubbleContent.systemSymbolAvailable(name), name)
        }
        XCTAssertFalse(BubbleContent.systemSymbolAvailable("no.such.symbol.exists"))
    }

    func testHintMentionsTheToggleBackBinding() throws {
        let content = BubbleContent(
            suggestion: try BubbleRender.suggestion("ctrl-alt-3", backAndForth: "ctrl-alt-tab"),
            symbolAvailable: { _ in true }
        )
        XCTAssertEqual(content.hint, "or ⌃⌥ ⇥ to toggle back")
    }
}
