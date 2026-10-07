import XCTest
@testable import AeroCheatCore

/// Replays a sanitised stream (workspace numbers and synthetic window ids only) through the classifier.
/// The fixture is shaped after real captures: Dock and Mission Control clicks, a keyboard switch, a Cmd-Tab, focus-only events.
final class GoldenReplayTests: XCTestCase {
    private struct Line: Decodable {
        struct Since: Decodable {
            let down: Double
            let up: Double
            let key: Double?
            let flags: Double?
        }
        let t: Double
        let since: Since
        let event: [String: AnyDecodable]
    }

    private struct AnyDecodable: Decodable {
        let value: Any
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let i = try? c.decode(Int.self) { value = i } else { value = try c.decode(String.self) }
        }
    }

    private func replay(_ fixture: String) throws -> [BurstVerdict] {
        let url = try XCTUnwrap(Bundle.module.url(forResource: fixture, withExtension: nil, subdirectory: "Fixtures"))
        let text = try String(contentsOf: url, encoding: .utf8)
        var classifier = BurstClassifier()
        var verdicts: [BurstVerdict] = []
        for raw in text.split(separator: "\n") {
            let line = try JSONDecoder().decode(Line.self, from: Data(raw.utf8))
            let eventJSON = try JSONSerialization.data(withJSONObject: line.event.mapValues(\.value))
            let event = try XCTUnwrap(AeroEvent.parse(line: String(decoding: eventJSON, as: UTF8.self)))
            let input = InputRecency(
                sinceLeftMouseDown: line.since.down,
                sinceLeftMouseUp: line.since.up,
                sinceKeyDown: line.since.key ?? .infinity,
                sinceFlagsChanged: line.since.flags ?? .infinity
            )
            if let verdict = classifier.ingest(event, at: line.t, input: input) { verdicts.append(verdict) }
        }
        if let verdict = classifier.flush() { verdicts.append(verdict) }
        return verdicts
    }

    func testVerdictsOfTheMissionControlSessions() throws {
        XCTAssertEqual(try replay("mission-control-replay.jsonl"), [
            .mouse(MouseSwitch(from: "1", to: "2")),                            // Dock icon click
            .mouse(MouseSwitch(from: "2", to: "1", returnsToPrevious: true)),   // Mission Control click, 77 ms
            .mouse(MouseSwitch(from: "1", to: "3")),                            // Mission Control click, 262 ms
            .keyboard(binding: "ctrl-alt-1"),
            .mouseFocus(FocusSwitch(windowId: 12, workspace: "1", previousWindowId: 11)),   // Dock window list, same workspace, 403 ms
            .ignored(.keyAfterClick),                                           // click, then a key 0.6 s later
            .ignored(.noRecentClick),                                           // Cmd-Tab long after the last click
            .ignored(.noFocusChange),                                           // focus event on the window already focused
            // Known limitation: a click that itself opens another app on another workspace has the shape of a
            // Mission Control click and is still taken for a mouse switch. Telling them apart needs the click's target.
            .mouse(MouseSwitch(from: "3", to: "1")),
        ])
    }
}
