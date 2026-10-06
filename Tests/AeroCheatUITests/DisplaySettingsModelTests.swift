import AeroCheatCore
import AeroCheatUI
import XCTest

final class DisplaySettingsModelTests: XCTestCase {
    private var suiteName = ""
    private var suite: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "AeroCheatUITests-\(UUID().uuidString)"
        suite = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        suite.removePersistentDomain(forName: suiteName)
        suite = nil
        super.tearDown()
    }

    func testChangesAreSavedAndReloaded() {
        let model = DisplaySettingsModel(storage: DisplaySettingsStorage(defaults: suite))
        XCTAssertEqual(model.settings, DisplaySettings())
        model.settings.anchor = .middleLeft
        model.settings.duration = 8
        let reloaded = DisplaySettingsModel(storage: DisplaySettingsStorage(defaults: suite))
        XCTAssertEqual(reloaded.settings.anchor, .middleLeft)
        XCTAssertEqual(reloaded.settings.duration, 8)
    }

    func testObserversHearEveryChangeWithTheClampedValue() {
        let model = DisplaySettingsModel(storage: DisplaySettingsStorage(defaults: suite))
        var heard: [DisplaySettings] = []
        model.addObserver { heard.append($0) }
        model.settings.tipInterval = 9999
        XCTAssertEqual(heard.count, 1)
        XCTAssertEqual(heard.last?.tipInterval, DisplaySettings.tipIntervalRange.upperBound)
        XCTAssertEqual(model.settings.tipInterval, DisplaySettings.tipIntervalRange.upperBound)
        model.settings.tipInterval = DisplaySettings.tipIntervalRange.upperBound
        XCTAssertEqual(heard.count, 1, "no change, no notification")
    }

    func testResetGoesBackToTheDefaultsAndForgetsTheStore() {
        let model = DisplaySettingsModel(storage: DisplaySettingsStorage(defaults: suite))
        var heard = 0
        model.settings.anchor = .bottomRight
        model.settings.iconsForModifiers = false
        model.addObserver { _ in heard += 1 }
        model.resetToDefaults()
        XCTAssertEqual(model.settings, DisplaySettings())
        XCTAssertEqual(heard, 1)
        XCTAssertEqual(DisplaySettingsStorage(defaults: suite).load(), DisplaySettings())
    }

    func testInMemoryModelNeverTouchesUserDefaults() {
        let model = DisplaySettingsModel(inMemory: DisplaySettings())
        model.settings.anchor = .center
        XCTAssertEqual(model.settings.anchor, .center)
        XCTAssertEqual(DisplaySettingsStorage(defaults: suite).load(), DisplaySettings())
        XCTAssertTrue(suite.dictionaryRepresentation().keys.allSatisfy { !$0.hasPrefix("display.") })
    }

    func testInMemoryModelStartsFromTheGivenSettingsClamped() {
        var s = DisplaySettings()
        s.duration = 1000
        XCTAssertEqual(DisplaySettingsModel(inMemory: s).settings.duration, DisplaySettings.durationRange.upperBound)
    }
}
