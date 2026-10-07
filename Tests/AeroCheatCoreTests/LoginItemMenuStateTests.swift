import XCTest
@testable import AeroCheatCore

final class LoginItemMenuStateTests: XCTestCase {
    func testEnabledIsCheckedWithoutDetail() {
        let state = LoginItemMenuState(status: .enabled)
        XCTAssertTrue(state.isChecked)
        XCTAssertTrue(state.isEnabled)
        XCTAssertNil(state.detail)
    }

    func testRequiresApprovalExplainsAndOffersSettings() {
        let state = LoginItemMenuState(status: .requiresApproval)
        XCTAssertFalse(state.isChecked)
        XCTAssertNotNil(state.detail)
        XCTAssertTrue(state.offersSettings)
    }

    func testOutsideBundleIsDisabledWithExplanation() {
        let state = LoginItemMenuState(status: .notInBundle)
        XCTAssertFalse(state.isEnabled)
        XCTAssertNotNil(state.detail)
    }
}
