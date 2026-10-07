import XCTest
@testable import AeroCheatCore

final class AeroSpaceConfigTests: XCTestCase {
    private func fixtureURL(_ name: String = "sample-aerospace.toml") throws -> URL {
        try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"))
    }

    private func fixtureModes() throws -> [BindingMode] {
        let text = try String(contentsOf: fixtureURL(), encoding: .utf8)
        return try AeroSpaceConfig.parse(text)
    }

    func testGroupsBindingsByModeInFileOrder() throws {
        let modes = try fixtureModes()
        XCTAssertEqual(modes.map(\.name), ["main", "service"])
        XCTAssertEqual(modes[0].bindings.map(\.combo.raw), [
            "alt-h", "alt-j", "ctrl-alt-shift-slash", "cmd-shift-1", "alt-tab", "alt-shift-semicolon",
        ])
        XCTAssertEqual(modes[1].bindings.map(\.combo.raw), ["esc", "r"])
    }

    func testIgnoresOtherTables() throws {
        let all = try fixtureModes().flatMap(\.bindings)
        XCTAssertFalse(all.contains { $0.command == "layout floating" })
    }

    func testStringAndArrayCommands() throws {
        let modes = try fixtureModes()
        XCTAssertEqual(modes[0].bindings[0].commands, ["focus left"])
        XCTAssertEqual(modes[1].bindings[0].commands, ["reload-config", "mode main"])
        XCTAssertEqual(modes[1].bindings[0].command, "reload-config; mode main")
    }

    func testTrailingCommentsAreStripped() throws {
        let binding = try XCTUnwrap(fixtureModes()[0].bindings.first { $0.combo.raw == "ctrl-alt-shift-slash" })
        XCTAssertEqual(binding.command, "layout tiles horizontal vertical")
    }

    func testModifierDisplayUsesMacOSOrder() {
        let combo = KeyCombo(raw: "cmd-shift-alt-ctrl-h")
        XCTAssertEqual(combo.modifiers, [.ctrl, .alt, .shift, .cmd])
        XCTAssertEqual(combo.display, "⌃⌥⇧⌘ H")
        XCTAssertEqual(combo.modifierWords, "ctrl alt shift cmd")
    }

    func testKeyGlyphs() {
        XCTAssertEqual(KeyCombo(raw: "alt-slash").display, "⌥ /")
        XCTAssertEqual(KeyCombo(raw: "alt-minus").keyDisplay, "-")
        XCTAssertEqual(KeyCombo(raw: "ctrl-alt-tab").display, "⌃⌥ ⇥")
        XCTAssertEqual(KeyCombo(raw: "esc").display, "⎋")
        XCTAssertEqual(KeyCombo(raw: "alt-f12").keyDisplay, "F12")
        XCTAssertEqual(KeyCombo(raw: "alt-1").keyDisplay, "1")
    }

    func testMissingBindingTablesYieldNoModes() throws {
        XCTAssertEqual(try AeroSpaceConfig.parse("config-version = 2\n[gaps]\ninner.horizontal = 8\n"), [])
    }

    func testDottedKeysOutsideTableHeader() throws {
        let modes = try AeroSpaceConfig.parse("mode.main.binding.alt-h = 'focus left'\n")
        XCTAssertEqual(modes.first?.bindings.first?.combo.raw, "alt-h")
    }

    func testSyntaxErrorReportsLine() {
        XCTAssertThrowsError(try AeroSpaceConfig.parse("[mode.main.binding]\nalt-h = 'focus left\n")) { error in
            guard case AeroSpaceConfigError.syntax(let toml) = error else {
                return XCTFail("unexpected error \(error)")
            }
            XCTAssertEqual(toml.line, 2)
        }
    }

    func testNonStringBindingIsRejected() {
        XCTAssertThrowsError(try AeroSpaceConfig.parse("[mode.main.binding]\nalt-h = 42\n")) { error in
            XCTAssertEqual(error as? AeroSpaceConfigError, .invalidBinding(mode: "main", key: "alt-h"))
        }
    }

    // MARK: Loader

    func testLoaderReportsDanglingSymlinkAsMissing() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("aerocheat-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let link = dir.appendingPathComponent("dangling.toml")
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: dir.path + "/gone.toml")
        XCTAssertEqual(AeroSpaceConfigLoader.load(paths: [link.path]), .missing(searched: [link.path]))
    }

}

final class BindingFilterTests: XCTestCase {
    private let modes = [
        BindingMode(name: "main", bindings: [
            Binding(combo: KeyCombo(raw: "alt-h"), commands: ["focus left"]),
            Binding(combo: KeyCombo(raw: "ctrl-alt-shift-h"), commands: ["move left"]),
            Binding(combo: KeyCombo(raw: "alt-1"), commands: ["workspace 1"]),
        ]),
        BindingMode(name: "service", bindings: [
            Binding(combo: KeyCombo(raw: "esc"), commands: ["reload-config", "mode main"]),
        ]),
    ]

    func testEmptyQueryKeepsEverything() {
        XCTAssertEqual(BindingFilter.apply("  ", to: modes), modes)
    }

    func testMatchesCommand() {
        let result = BindingFilter.apply("move", to: modes)
        XCTAssertEqual(result.map(\.name), ["main"])
        XCTAssertEqual(result[0].bindings.map(\.combo.raw), ["ctrl-alt-shift-h"])
    }

    func testMatchesSpelledOutModifiersAndSymbols() {
        XCTAssertEqual(BindingFilter.apply("shift", to: modes)[0].bindings.map(\.combo.raw), ["ctrl-alt-shift-h"])
        XCTAssertEqual(BindingFilter.apply("⇧", to: modes)[0].bindings.map(\.combo.raw), ["ctrl-alt-shift-h"])
    }

    func testAllWordsMustMatchAndCaseIsIgnored() {
        XCTAssertEqual(BindingFilter.apply("ALT left", to: modes)[0].bindings.map(\.combo.raw), ["alt-h", "ctrl-alt-shift-h"])
        XCTAssertTrue(BindingFilter.apply("alt reload", to: modes).isEmpty)
    }

}

final class MiniTOMLTests: XCTestCase {
    func testStringForms() throws {
        let entries = try MiniTOML.parse("""
        a = "x\\ty\\u00e9"
        b = 'raw \\n'
        c = \"\"\"
        line1
        line2\"\"\"
        """)
        XCTAssertEqual(entries.map(\.value), [.string("x\ty\u{e9}"), .string("raw \\n"), .string("line1\nline2")])
    }

    func testQuotedAndDottedKeys() throws {
        let entries = try MiniTOML.parse("[t]\n\"a.b\".c = 1\n")
        XCTAssertEqual(entries.first?.path, ["t", "a.b", "c"])
        XCTAssertEqual(entries.first?.value, .other("1"))
    }

    func testInlineTableAndNestedArrays() throws {
        let entries = try MiniTOML.parse("x = { a = 'b}', c = [1, 2] }\ny = [['a'], ['b']]\n")
        XCTAssertEqual(entries[0].value, .other("{ a = 'b}', c = [1, 2] }"))
        XCTAssertEqual(entries[1].value, .array([.array([.string("a")]), .array([.string("b")])]))
    }

    func testRejectsGarbageAfterValue() {
        XCTAssertThrowsError(try MiniTOML.parse("a = 'x' 'y'\n"))
    }
}
