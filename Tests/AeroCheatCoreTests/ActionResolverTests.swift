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
        XCTAssertEqual(Action(command: "focus left"), .focus(.left))
        XCTAssertEqual(Action(command: "focus --ignore-floating down"), .focus(.down))
        XCTAssertEqual(Action(command: "focus dfs-next"), .other("focus dfs-next"))
        XCTAssertEqual(Action(command: "focus --window-id 123"), .other("focus --window-id 123"))
        XCTAssertEqual(Action(command: "focus left right"), .other("focus left right"))
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

    // MARK: focus suggestions

    private let horizontalConfig = """
    [mode.main.binding]
    ctrl-alt-h = 'focus left'
    ctrl-alt-l = 'focus right'
    ctrl-alt-k = 'focus up'
    ctrl-alt-j = 'focus down'
    ctrl-alt-1 = 'workspace 1'
    """

    private let click = FocusSwitch(windowId: 2, workspace: "1", previousWindowId: 1, pointer: CGPoint(x: 600, y: 400))

    func testAccordionFocusSuggestsTheAxisPair() throws {
        let r = try resolver(horizontalConfig)
        let horizontal = try XCTUnwrap(r.suggestion(for: click, layout: .accordion(.horizontal), windowFrame: nil))
        XCTAssertEqual(horizontal.keys, "⌃⌥ H")
        XCTAssertEqual(horizontal.title, "focus left")
        XCTAssertEqual(horizontal.hint, "or ⌃⌥ L to focus right")
        XCTAssertEqual(horizontal.trigger, .focusChange)
        XCTAssertEqual(horizontal.key, "ctrl-alt-h")
        XCTAssertEqual(horizontal.relatedKeys, ["ctrl-alt-l"])

        let vertical = try XCTUnwrap(r.suggestion(for: click, layout: .accordion(.vertical), windowFrame: nil))
        XCTAssertEqual(vertical.keys, "⌃⌥ K")
        XCTAssertEqual(vertical.hint, "or ⌃⌥ J to focus down")
    }

    func testWorkspaceSuggestionsKeepTheirTrigger() throws {
        let r = try resolver(horizontalConfig)
        XCTAssertEqual(r.suggestion(for: MouseSwitch(from: "2", to: "1"))?.trigger, .workspaceSwitch)
    }

    func testPairUsesWhicheverBindingExists() throws {
        let onlyRight = try resolver("[mode.main.binding]\nalt-l = 'focus right'")
        let suggestion = try XCTUnwrap(onlyRight.suggestion(for: click, layout: .accordion(.horizontal), windowFrame: nil))
        XCTAssertEqual(suggestion.title, "focus right")
        XCTAssertNil(suggestion.hint)
        XCTAssertTrue(onlyRight.hasFocusBindings)
    }

    func testNoFocusBindingOnTheAxisMeansSilence() throws {
        let verticalOnly = try resolver("[mode.main.binding]\nalt-k = 'focus up'\nalt-j = 'focus down'")
        XCTAssertNil(verticalOnly.suggestion(for: click, layout: .accordion(.horizontal), windowFrame: nil))
        let none = try resolver("[mode.main.binding]\nalt-1 = 'workspace 1'")
        XCTAssertFalse(none.hasFocusBindings)
        XCTAssertNil(none.suggestion(for: click, layout: .accordion(.horizontal), windowFrame: nil))
    }

    func testFirstFocusBindingInFileOrderWins() throws {
        let r = try resolver("[mode.main.binding]\nalt-h = 'focus left'\nctrl-alt-h = 'focus left'\nalt-l = 'focus right'")
        XCTAssertEqual(r.suggestion(for: click, layout: .accordion(.horizontal), windowFrame: nil)?.key, "alt-h")
    }

    func testFloatingFullscreenAndUnknownLayoutsAreSilent() throws {
        let r = try resolver(horizontalConfig)
        for layout in [WindowLayout.floating, .nativeFullscreen, .other("macos_native_hidden_app")] {
            XCTAssertNil(r.suggestion(for: click, layout: layout, windowFrame: nil), "\(layout)")
        }
    }

    func testTilesStaySilentForADirectClick() throws {
        let r = try resolver(horizontalConfig)
        let frame = CGRect(x: 500, y: 300, width: 400, height: 300)   // contains the pointer
        XCTAssertNil(r.suggestion(for: click, layout: .tiles(.horizontal), windowFrame: frame))
    }

    func testTilesSuggestWhenThePointerIsOutsideTheNewWindow() throws {
        let r = try resolver(horizontalConfig)
        let frame = CGRect(x: 900, y: 300, width: 400, height: 300)   // elsewhere: Mission Control, Dock menu
        XCTAssertEqual(r.suggestion(for: click, layout: .tiles(.horizontal), windowFrame: frame)?.keys, "⌃⌥ H")
    }

    func testTilesStaySilentWhenGeometryIsUnknown() throws {
        let r = try resolver(horizontalConfig)
        XCTAssertNil(r.suggestion(for: click, layout: .tiles(.horizontal), windowFrame: nil))
        let noPointer = FocusSwitch(windowId: 2, workspace: "1", previousWindowId: 1)
        XCTAssertNil(r.suggestion(for: noPointer, layout: .tiles(.horizontal), windowFrame: CGRect(x: 900, y: 300, width: 400, height: 300)))
    }
}
