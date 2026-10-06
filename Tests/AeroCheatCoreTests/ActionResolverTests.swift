import XCTest
@testable import AeroCheatCore

final class ActionResolverTests: XCTestCase {
    private func resolver(_ toml: String) throws -> ActionResolver {
        ActionResolver(modes: try AeroSpaceConfig.parse(toml))
    }

    func testCommandCanonicalisation() {
        XCTAssertEqual(Action(command: "workspace 3"), .workspace("3"))
        XCTAssertEqual(Action(command: "workspace --auto-back-and-forth 3"), .workspace("3"))
        XCTAssertEqual(Action(command: "workspace-back-and-forth"), .workspaceBackAndForth)
        XCTAssertEqual(Action(command: "workspace next"), .other("workspace next"))
        XCTAssertEqual(Action(command: "focus left"), .other("focus left"))
    }

    func testResolvesWorkspaceSwitchToItsBinding() throws {
        let r = try resolver("""
        [mode.main.binding]
        ctrl-alt-3 = 'workspace 3'
        """)
        let suggestion = try XCTUnwrap(r.suggestion(for: MouseSwitch(from: "1", to: "3")))
        XCTAssertEqual(suggestion.keys, "⌃⌥ 3")
        XCTAssertEqual(suggestion.title, "switch to workspace 3")
        XCTAssertEqual(suggestion.summary, "⌃⌥ 3 — switch to workspace 3")
        XCTAssertNil(suggestion.hint)
    }

    func testNoBindingMeansNoSuggestion() throws {
        let r = try resolver("""
        [mode.main.binding]
        ctrl-alt-3 = 'workspace 3'
        """)
        XCTAssertNil(r.suggestion(for: MouseSwitch(from: "1", to: "7")))
    }

    func testChainedBindingsAreNotIndexed() throws {
        let r = try resolver("""
        [mode.main.binding]
        alt-1 = ['workspace 1', 'layout tiles']
        """)
        XCTAssertNil(r.binding(for: .workspace("1")))
    }

    func testFirstBindingInFileOrderWins() throws {
        let r = try resolver("""
        [mode.main.binding]
        alt-1 = 'workspace 1'
        ctrl-alt-1 = 'workspace --auto-back-and-forth 1'
        """)
        XCTAssertEqual(r.binding(for: .workspace("1"))?.combo.raw, "alt-1")
    }

    func testOnlyTheMainModeIsUsed() throws {
        let r = try resolver("""
        [mode.service.binding]
        r = 'workspace 1'
        """)
        XCTAssertNil(r.binding(for: .workspace("1")))
    }

    func testToggleBackHint() throws {
        let r = try resolver("""
        [mode.main.binding]
        ctrl-alt-2 = 'workspace 2'
        ctrl-alt-tab = 'workspace-back-and-forth'
        """)
        let back = try XCTUnwrap(r.suggestion(for: MouseSwitch(from: "1", to: "2", returnsToPrevious: true)))
        XCTAssertEqual(back.hint, "or ⌃⌥ ⇥ to toggle back")
        let plain = try XCTUnwrap(r.suggestion(for: MouseSwitch(from: "1", to: "2")))
        XCTAssertNil(plain.hint)
    }

    func testCanonicalComboIgnoresModifierOrderAndCase() {
        XCTAssertEqual(KeyCombo(raw: "alt-ctrl-3").canonical, KeyCombo(raw: "ctrl-alt-3").canonical)
        XCTAssertEqual(KeyCombo(raw: "ctrl-alt-H").canonical, "ctrl-alt-h")
    }
}
