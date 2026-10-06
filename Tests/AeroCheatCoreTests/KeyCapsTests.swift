import XCTest
@testable import AeroCheatCore

final class KeyCapsTests: XCTestCase {
    func testModifiersBecomeSymbolsInDisplayOrderThenKeyText() {
        let caps = KeyCombo(raw: "cmd-shift-alt-ctrl-h").keyCaps
        XCTAssertEqual(caps, [
            .symbol(name: "control", glyph: "⌃"),
            .symbol(name: "option", glyph: "⌥"),
            .symbol(name: "shift", glyph: "⇧"),
            .symbol(name: "command", glyph: "⌘"),
            .text("H"),
        ])
    }

    func testNonModifierKeysStayText() {
        XCTAssertEqual(KeyCombo(raw: "alt-tab").keyCaps.last, .text("⇥"))
        XCTAssertEqual(KeyCombo(raw: "alt-left").keyCaps.last, .text("←"))
        XCTAssertEqual(KeyCombo(raw: "alt-3").keyCaps.last, .text("3"))
        XCTAssertEqual(KeyCombo(raw: "enter").keyCaps, [.text("↩")])
    }

    func testIconWhenSymbolAvailable() {
        let cap = KeyCap.symbol(name: "option", glyph: "⌥")
        XCTAssertEqual(cap.rendering(symbolAvailable: { _ in true }), .icon("option"))
    }

    func testGlyphFallbackWhenSymbolUnavailable() {
        let cap = KeyCap.symbol(name: "option", glyph: "⌥")
        XCTAssertEqual(cap.rendering(symbolAvailable: { _ in false }), .text("⌥"))
        XCTAssertEqual(KeyCap.text("3").rendering(symbolAvailable: { _ in false }), .text("3"))
    }
}
