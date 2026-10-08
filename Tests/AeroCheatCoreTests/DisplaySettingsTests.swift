import XCTest
@testable import AeroCheatCore

final class DisplaySettingsTests: XCTestCase {
    private var suiteName = ""
    private var suite: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "AeroCheatTests-\(UUID().uuidString)"
        suite = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        suite.removePersistentDomain(forName: suiteName)
        suite = nil
        super.tearDown()
    }

    private var storage: DisplaySettingsStorage { DisplaySettingsStorage(defaults: suite) }

    // MARK: Defaults

    func testDefaultsAreTheShippedBehaviour() {
        let s = DisplaySettings()
        XCTAssertEqual(s.anchor, .topRight)
        XCTAssertEqual(s.horizontalMargin, 16)
        XCTAssertEqual(s.verticalMargin, 80)
        XCTAssertNil(s.backgroundColor)
        XCTAssertNil(s.textColor)
        XCTAssertNil(s.iconTint)
        XCTAssertEqual(s.opacity, 1)
        XCTAssertEqual(s.duration, 4)
        XCTAssertEqual(s.scale, 1)
        XCTAssertTrue(s.iconsForModifiers)
        XCTAssertEqual(s.tipInterval, 5)
        XCTAssertEqual(s.identicalTipInterval, 30)
        for kind in SuggestionKind.allCases { XCTAssertTrue(s.isEnabled(kind), "\(kind)") }
        XCTAssertEqual(s.normalized(), s)
    }

    // MARK: Persistence

    func testRoundTripThroughAThrowawaySuite() {
        var s = DisplaySettings()
        s.anchor = .bottomCenter
        s.horizontalMargin = 40
        s.verticalMargin = 12.5
        s.backgroundColor = SettingsColor(red: 0.1, green: 0.2, blue: 0.3)
        s.textColor = SettingsColor(red: 1, green: 1, blue: 0)
        s.iconTint = SettingsColor(red: 0, green: 0.5, blue: 1)
        s.opacity = 0.7
        s.duration = 9
        s.scale = 1.25
        s.iconsForModifiers = false
        s.setEnabled(.workspaceSwitch, false)
        s.tipInterval = 12
        s.identicalTipInterval = 90
        storage.save(s)
        XCTAssertEqual(storage.load(), s)
        // A fresh handle on the same suite sees it too: it really was persisted.
        XCTAssertEqual(DisplaySettingsStorage(defaults: UserDefaults(suiteName: suiteName)!).load(), s)
    }

    func testClearingAColourGoesBackToTheSystemLook() {
        var s = DisplaySettings()
        s.backgroundColor = SettingsColor(red: 1, green: 0, blue: 0)
        storage.save(s)
        s.backgroundColor = nil
        storage.save(s)
        XCTAssertNil(storage.load().backgroundColor)
    }

    func testClearForgetsEverything() {
        var s = DisplaySettings()
        s.anchor = .center
        s.duration = 20
        storage.save(s)
        storage.clear()
        XCTAssertEqual(storage.load(), DisplaySettings())
        XCTAssertTrue(suite.dictionaryRepresentation().keys.allSatisfy { !$0.hasPrefix(DisplaySettingsStorage.prefix) })
    }

    // MARK: Clamping and corrupt values

    func testOutOfRangeValuesAreClamped() {
        var s = DisplaySettings()
        s.horizontalMargin = -5
        s.verticalMargin = 9999
        s.opacity = 0
        s.duration = 500
        s.scale = 0.1
        s.tipInterval = -1
        s.identicalTipInterval = 1e9
        s.backgroundColor = SettingsColor(red: 2, green: -1, blue: 0.5)
        let n = s.normalized()
        XCTAssertEqual(n.horizontalMargin, DisplaySettings.marginRange.lowerBound)
        XCTAssertEqual(n.verticalMargin, DisplaySettings.marginRange.upperBound)
        XCTAssertEqual(n.opacity, DisplaySettings.opacityRange.lowerBound)
        XCTAssertEqual(n.duration, DisplaySettings.durationRange.upperBound)
        XCTAssertEqual(n.scale, DisplaySettings.scaleRange.lowerBound)
        XCTAssertEqual(n.tipInterval, DisplaySettings.tipIntervalRange.lowerBound)
        XCTAssertEqual(n.identicalTipInterval, DisplaySettings.identicalTipIntervalRange.upperBound)
        XCTAssertEqual(n.backgroundColor, SettingsColor(red: 1, green: 0, blue: 0.5))
    }

    func testNonFiniteValuesFallBackToTheDefault() {
        var s = DisplaySettings()
        s.duration = .nan
        s.opacity = .infinity
        s.verticalMargin = -.infinity
        s.textColor = SettingsColor(red: .nan, green: 0, blue: 0)
        let n = s.normalized()
        XCTAssertEqual(n.duration, 4)
        XCTAssertEqual(n.opacity, 1)
        XCTAssertEqual(n.verticalMargin, 80)
        XCTAssertNil(n.textColor)
    }

    func testStoredOutOfRangeValuesAreClampedOnLoad() {
        suite.set(900.0, forKey: "display.duration")
        suite.set(-20.0, forKey: "display.horizontalMargin")
        let s = storage.load()
        XCTAssertEqual(s.duration, DisplaySettings.durationRange.upperBound)
        XCTAssertEqual(s.horizontalMargin, 0)
    }

    func testCorruptStoredValuesFallBackFieldByField() {
        var good = DisplaySettings()
        good.tipInterval = 7
        storage.save(good)
        suite.set("not a number", forKey: "display.duration")
        suite.set("middleNowhere", forKey: "display.anchor")
        suite.set([1, 2], forKey: "display.backgroundColor")
        suite.set("red", forKey: "display.textColor")
        suite.set(["a", "b", "c"], forKey: "display.iconTint")
        suite.set(Data([1, 2, 3]), forKey: "display.scale")
        suite.set("yes", forKey: "display.iconsForModifiers")
        suite.set(42, forKey: "display.disabledKinds")
        suite.set(Double.nan, forKey: "display.opacity")
        let s = storage.load()
        XCTAssertEqual(s.duration, 4)
        XCTAssertEqual(s.anchor, .topRight)
        XCTAssertNil(s.backgroundColor)
        XCTAssertNil(s.textColor)
        XCTAssertNil(s.iconTint)
        XCTAssertEqual(s.scale, 1)
        XCTAssertTrue(s.iconsForModifiers)
        XCTAssertTrue(s.disabledKinds.isEmpty)
        XCTAssertEqual(s.opacity, 1)
        XCTAssertEqual(s.tipInterval, 7, "a healthy field next to corrupt ones is kept")
    }

    func testUnknownStoredKindsAreIgnoredAndNewKindsStayOn() {
        suite.set(["someFutureKind", "workspaceSwitch"], forKey: "display.disabledKinds")
        XCTAssertEqual(storage.load().disabledKinds, [.workspaceSwitch])
        suite.set([String](), forKey: "display.disabledKinds")
        XCTAssertTrue(storage.load().disabledKinds.isEmpty)
    }

    // MARK: Kinds and policy delays

    private func suggestion(_ workspace: String) throws -> Suggestion {
        let modes = try AeroSpaceConfig.parse("""
        [mode.main.binding]
        ctrl-alt-1 = 'workspace 1'
        ctrl-alt-2 = 'workspace 2'
        """)
        return try XCTUnwrap(ActionResolver(modes: modes).suggestion(for: MouseSwitch(from: "9", to: workspace)))
    }

    func testEachSuggestionKindCanBeSwitchedOffAlone() throws {
        let modes = try AeroSpaceConfig.parse("""
        [mode.main.binding]
        ctrl-alt-h = 'focus left'
        ctrl-alt-l = 'focus right'
        """)
        let click = FocusSwitch(windowId: 2, workspace: "1", previousWindowId: 1, pointer: CGPoint(x: 600, y: 400))
        let focus = try XCTUnwrap(ActionResolver(modes: modes).suggestion(for: click, layout: .accordion(.horizontal), windowFrame: nil))
        let workspace = try suggestion("1")
        XCTAssertEqual(workspace.kind, .workspaceSwitch)
        XCTAssertEqual(focus.kind, .focusChange)
        var s = DisplaySettings()
        s.setEnabled(.focusChange, false)
        XCTAssertFalse(s.isEnabled(focus.kind))
        XCTAssertTrue(s.isEnabled(workspace.kind))
        s.setEnabled(.focusChange, true)
        s.setEnabled(.workspaceSwitch, false)
        XCTAssertTrue(s.isEnabled(focus.kind))
        XCTAssertFalse(s.isEnabled(workspace.kind))
    }

    func testPolicyAppliesNewDelaysLiveAndKeepsItsHistory() throws {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        var policy = SuggestionPolicy(clock: { now })
        XCTAssertEqual(policy.consider(try suggestion("1")), .show)
        now.addTimeInterval(3)
        XCTAssertEqual(policy.consider(try suggestion("2")), .suppressed(.rateLimited))

        var s = DisplaySettings()
        s.tipInterval = 1
        policy.limits = s.policyLimits
        XCTAssertEqual(policy.consider(try suggestion("2")), .show, "the shorter delay applies at once")
        now.addTimeInterval(10)
        XCTAssertEqual(policy.consider(try suggestion("1")), .suppressed(.cooldown), "the shown history is kept")

        s.identicalTipInterval = 5
        policy.limits = s.policyLimits
        XCTAssertEqual(policy.consider(try suggestion("1")), .show)
    }

    func testPreviewSuggestionComesFromTheDemoConfigAndShowsTheHint() throws {
        let preview = try XCTUnwrap(DemoScript.previewSuggestion())
        XCTAssertEqual(preview.keys, "⌃⌥ 2")
        XCTAssertNotNil(preview.hint)
    }

    // MARK: Ignore

    func testIgnoredAppsMatchNameOrBundleIDAndRoundTrip() {
        var s = DisplaySettings()
        XCTAssertTrue(s.ignoreDock)
        s.ignoredApps = DisplaySettings.appList(" Finder, com.apple.Safari,,\nfinder ")
        XCTAssertEqual(s.ignoredApps, ["Finder", "com.apple.Safari"])
        XCTAssertTrue(s.ignores(AppIdentity(name: "finder", bundleID: "com.apple.finder")))
        XCTAssertTrue(s.ignores(AppIdentity(name: "Safari", bundleID: "COM.APPLE.SAFARI")))
        XCTAssertFalse(s.ignores(AppIdentity(name: "Terminal", bundleID: "com.apple.Terminal")))
        XCTAssertFalse(s.ignores(nil))
        s.ignoreDock = false
        storage.save(s)
        XCTAssertEqual(storage.load(), s)
    }
}
