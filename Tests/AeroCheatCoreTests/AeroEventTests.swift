import XCTest
@testable import AeroCheatCore

final class AeroEventTests: XCTestCase {
    func testParsesTheEventsActiveModeNeeds() {
        XCTAssertEqual(
            AeroEvent.parse(line: #"{"_event":"binding-triggered","binding":"ctrl-alt-3","mode":"main"}"#),
            .bindingTriggered(binding: "ctrl-alt-3", mode: "main")
        )
        XCTAssertEqual(
            AeroEvent.parse(line: #"{"_event":"focus-changed","windowId":7,"workspace":"2"}"#),
            .focusChanged(windowId: 7, workspace: "2")
        )
        XCTAssertEqual(
            AeroEvent.parse(line: #"{"_event":"focused-workspace-changed","prevWorkspace":"1","workspace":"2"}"#),
            .focusedWorkspaceChanged(prev: "1", workspace: "2")
        )
        XCTAssertEqual(AeroEvent.parse(line: #"{"_event":"mode-changed","mode":"service"}"#), .modeChanged(mode: "service"))
    }

    func testToleratesUnknownEventsFieldsAndGarbage() {
        XCTAssertNil(AeroEvent.parse(line: #"{"_event":"window-detected","windowId":1}"#))
        XCTAssertNil(AeroEvent.parse(line: "not json"))
        XCTAssertNil(AeroEvent.parse(line: #"{"_event":"focused-workspace-changed","workspace":"2"}"#))
        XCTAssertEqual(
            AeroEvent.parse(line: #"{"_event":"mode-changed","mode":"main","future":{"x":1}}"#),
            .modeChanged(mode: "main")
        )
    }

    func testLineBufferHandlesPartialChunks() {
        var buffer = LineBuffer()
        XCTAssertEqual(buffer.append(Data("{\"a\":1}\n{\"b\"".utf8)), ["{\"a\":1}"])
        XCTAssertEqual(buffer.append(Data(":2}\n\n".utf8)), ["{\"b\":2}"])
        XCTAssertEqual(buffer.append(Data("x".utf8)), [])
    }

    func testVersionParsing() {
        XCTAssertEqual(AeroSpaceVersion.parse("aerospace CLI client version: 0.21.3-Beta d56e163"), AeroSpaceVersion(major: 0, minor: 21, patch: 3))
        XCTAssertEqual(AeroSpaceVersion.parse("0.20"), AeroSpaceVersion(major: 0, minor: 20, patch: 0))
        XCTAssertNil(AeroSpaceVersion.parse("no digits"))
    }

    func testVersionOutputTakesTheOldestOfCLIAndServer() {
        let output = """
        aerospace CLI client version: 0.21.3-Beta d56e163
        AeroSpace.app server version: 0.20.2-Beta aaaa
        """
        let version = AeroSpaceVersion.parse(versionOutput: output)
        XCTAssertEqual(version, AeroSpaceVersion(major: 0, minor: 20, patch: 2))
        XCTAssertTrue(version! < AeroSpaceVersion.minimumForSubscribe)
        XCTAssertFalse(AeroSpaceVersion(major: 0, minor: 21, patch: 0) < AeroSpaceVersion.minimumForSubscribe)
    }

    func testBinaryCandidatesPreferHomebrewThenPath() {
        XCTAssertEqual(
            AeroSpaceBinary.candidates(path: "/usr/bin:/opt/homebrew/bin:/foo"),
            ["/opt/homebrew/bin/aerospace", "/usr/local/bin/aerospace", "/usr/bin/aerospace", "/foo/aerospace"]
        )
        XCTAssertEqual(AeroSpaceBinary.candidates(path: nil).count, 2)
    }
}
