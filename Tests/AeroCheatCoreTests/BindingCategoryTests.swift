import XCTest
@testable import AeroCheatCore

final class BindingCategoryTests: XCTestCase {
    private func binding(_ key: String, _ commands: String...) -> Binding {
        Binding(combo: KeyCombo(raw: key), commands: commands)
    }

    func testCategoryComesFromTheFirstCommand() {
        XCTAssertEqual(BindingCategory(commands: ["focus left"]), .focus)
        XCTAssertEqual(BindingCategory(commands: ["move-node-to-workspace 3"]), .move)
        XCTAssertEqual(BindingCategory(commands: ["workspace-back-and-forth"]), .workspace)
        XCTAssertEqual(BindingCategory(commands: ["layout tiles horizontal vertical", "mode main"]), .layout)
        XCTAssertEqual(BindingCategory(commands: ["resize smart -50"]), .resize)
        XCTAssertEqual(BindingCategory(commands: ["fullscreen"]), .fullscreen)
        XCTAssertEqual(BindingCategory(commands: ["mode service"]), .other)
        XCTAssertEqual(BindingCategory(commands: []), .other)
    }

    func testSectionsFollowCategoryOrderAndKeepFileOrder() {
        let mode = BindingMode(name: "main", bindings: [
            binding("alt-1", "workspace 1"), binding("alt-h", "focus left"),
            binding("alt-2", "workspace 2"), binding("alt-shift-semicolon", "mode service"),
        ])
        XCTAssertEqual(mode.sections.map(\.category), [.focus, .workspace, .other])
        XCTAssertEqual(mode.sections[1].bindings.map(\.id), ["alt-1", "alt-2"])
    }

    func testSearchMatchesTheCategoryTitle() {
        let mode = BindingMode(name: "main", bindings: [binding("alt-1", "workspace 1"), binding("alt-h", "focus left")])
        XCTAssertEqual(BindingFilter.apply("workspaces", to: [mode]).first?.bindings.map(\.id), ["alt-1"])
    }

    func testRarelyUsedIsTheLeastPressedQuarterOnceThereIsEnoughData() {
        let keys = ["alt-1", "alt-2", "alt-3", "alt-4", "alt-5", "alt-6", "alt-7", "alt-8"]
        let mode = BindingMode(name: "main", bindings: keys.map { binding($0, "workspace \($0.last!)") })
        var usage = ShortcutUsage()
        usage.record(binding: "alt-1", mode: "main")
        XCTAssertTrue(usage.rarelyUsed(in: mode).isEmpty, "too few presses to compare")
        for (index, key) in keys.enumerated() {
            for _ in 0..<(index + 1) { usage.record(binding: key, mode: "main") }
        }
        XCTAssertEqual(usage.rarelyUsed(in: mode), ["alt-1", "alt-2"])
        // Another mode's presses and the modifier order do not matter.
        usage.record(binding: "alt-1", mode: "service")
        XCTAssertEqual(usage.count(of: KeyCombo(raw: "alt-8"), mode: "main"), 8)
    }
}
