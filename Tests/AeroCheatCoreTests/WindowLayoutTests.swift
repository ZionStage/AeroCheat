import XCTest
@testable import AeroCheatCore

final class WindowLayoutTests: XCTestCase {
    func testParsesTheLayoutsOfAeroSpace() {
        XCTAssertEqual(WindowLayout(raw: "h_tiles"), .tiles(.horizontal))
        XCTAssertEqual(WindowLayout(raw: "v_tiles"), .tiles(.vertical))
        XCTAssertEqual(WindowLayout(raw: "h_accordion"), .accordion(.horizontal))
        XCTAssertEqual(WindowLayout(raw: "v_accordion"), .accordion(.vertical))
        XCTAssertEqual(WindowLayout(raw: "floating"), .floating)
        XCTAssertEqual(WindowLayout(raw: "macos_native_fullscreen"), .nativeFullscreen)
        XCTAssertEqual(WindowLayout(raw: "macos_native_minimized"), .other("macos_native_minimized"))
    }

    func testOnlyFlatLayoutsHaveAnAxis() {
        XCTAssertEqual(WindowLayout.tiles(.vertical).axis, .vertical)
        XCTAssertEqual(WindowLayout.accordion(.horizontal).axis, .horizontal)
        XCTAssertNil(WindowLayout.floating.axis)
        XCTAssertNil(WindowLayout.nativeFullscreen.axis)
        XCTAssertNil(WindowLayout.other("x").axis)
    }

    func testFindsTheLayoutOfOneWindowInListWindowsOutput() {
        let output = "101 h_accordion\n102 h_accordion\n103 floating\n104 macos_native_fullscreen\n"
        XCTAssertEqual(WindowListQuery.layout(ofWindow: 102, in: output), .accordion(.horizontal))
        XCTAssertEqual(WindowListQuery.layout(ofWindow: 103, in: output), .floating)
        XCTAssertEqual(WindowListQuery.layout(ofWindow: 104, in: output), .nativeFullscreen)
    }

    func testUnlistedWindowOrOddOutputYieldsNil() {
        XCTAssertNil(WindowListQuery.layout(ofWindow: 9, in: "101 h_accordion\n"))
        XCTAssertNil(WindowListQuery.layout(ofWindow: 101, in: "101\nnot a window line\n101 a b\n"))
        XCTAssertNil(WindowListQuery.layout(ofWindow: 101, in: ""))
    }

    func testTheQueryIsReadOnly() {
        XCTAssertEqual(WindowListQuery.arguments.first, "list-windows")
        XCTAssertEqual(WindowListQuery.arguments.last, "%{window-id} %{window-layout}")
    }

    func testListsWindowOnlyWhenPresent() {
        let output = "101 h_tiles\n102 floating\n"
        XCTAssertTrue(WindowListQuery.lists(window: 102, in: output))
        XCTAssertFalse(WindowListQuery.lists(window: 103, in: output))
    }
}
