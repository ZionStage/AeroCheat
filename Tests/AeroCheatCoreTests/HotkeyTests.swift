import XCTest
@testable import AeroCheatCore

final class HotkeyTests: XCTestCase {
    private let keyC: UInt32 = 8
    private let keyK: UInt32 = 40

    func testDefaultIsControlOptionCommandC() {
        XCTAssertEqual(Hotkey.default.keyCode, keyC)
        XCTAssertEqual(Hotkey.default.display, "⌃⌥⌘C")
        XCTAssertEqual(Hotkey(raw: Hotkey.default.raw), .default)
    }

    func testValidationRefusesMissingModifiersMenuAndReservedCombos() {
        XCTAssertEqual(Hotkey.validate(keyCode: keyK, modifiers: []), .failure(.needsModifier))
        XCTAssertEqual(Hotkey.validate(keyCode: keyK, modifiers: [.shift]), .failure(.needsModifier))
        XCTAssertEqual(Hotkey.validate(keyCode: 12, modifiers: [.cmd]), .failure(.usedByMenu))
        XCTAssertEqual(Hotkey.validate(keyCode: 49, modifiers: [.cmd]), .failure(.reserved))
        XCTAssertEqual(Hotkey.validate(keyCode: 0xFFFF, modifiers: [.cmd]), .failure(.unsupportedKey))
        XCTAssertEqual(Hotkey.validate(keyCode: keyK, modifiers: [.ctrl, .cmd]).map(\.display), .success("⌃⌘K"))
    }

    func testValidationRefusesAComboTheAeroSpaceConfigBinds() {
        let modes = [BindingMode(name: "main", bindings: [Binding(combo: KeyCombo(raw: "alt-ctrl-k"), commands: ["focus up"])])]
        XCTAssertEqual(Hotkey.validate(keyCode: keyK, modifiers: [.ctrl, .alt], modes: modes), .failure(.boundInAeroSpace(command: "focus up")))
    }

    func testStoredComboRoundTripsAndAnUnknownKeyIsRefused() throws {
        let custom = try XCTUnwrap(Hotkey(keyCode: keyK, modifiers: [.cmd, .alt]))
        XCTAssertEqual(custom.raw, "alt-cmd-k")
        XCTAssertEqual(Hotkey(raw: "cmd-alt-k"), custom)
        XCTAssertNil(Hotkey(raw: "ctrl-nosuchkey"))
    }
}
