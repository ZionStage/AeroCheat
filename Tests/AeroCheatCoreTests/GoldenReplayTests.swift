import XCTest
@testable import AeroCheatCore

/// Replays a sanitised stream (workspace numbers and synthetic window ids only) through the classifier.
/// The fixture is shaped after real captures: keyboard presses, a focus bounce, mouse taps, a Cmd-Tab.
final class GoldenReplayTests: XCTestCase {
    private struct Line: Decodable {
        struct Since: Decodable { let down: Double; let up: Double }
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

    private func replay() throws -> [BurstVerdict] {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "golden-replay.jsonl", withExtension: nil, subdirectory: "Fixtures"))
        let text = try String(contentsOf: url, encoding: .utf8)
        var classifier = BurstClassifier()
        var verdicts: [BurstVerdict] = []
        for raw in text.split(separator: "\n") {
            let line = try JSONDecoder().decode(Line.self, from: Data(raw.utf8))
            let eventJSON = try JSONSerialization.data(withJSONObject: line.event.mapValues(\.value))
            let event = try XCTUnwrap(AeroEvent.parse(line: String(decoding: eventJSON, as: UTF8.self)))
            let input = InputRecency(sinceLeftMouseDown: line.since.down, sinceLeftMouseUp: line.since.up)
            if let verdict = classifier.ingest(event, at: line.t, input: input) { verdicts.append(verdict) }
        }
        if let verdict = classifier.flush() { verdicts.append(verdict) }
        return verdicts
    }

    func testVerdictsOfTheRecordedStream() throws {
        XCTAssertEqual(try replay(), [
            .keyboard(binding: "ctrl-alt-3"),
            .keyboard(binding: "ctrl-alt-1"),                                   // includes the focus bounce
            .mouse(MouseSwitch(from: "1", to: "2")),                            // Dock-zone tap
            .ignored(.noRecentClick),                                           // Cmd-Tab
            .mouse(MouseSwitch(from: "1", to: "3")),                            // second tap
            .ignored(.noWorkspaceChange),                                       // focus-only burst
            .ignored(.bounce),                                                  // independent bounce
        ])
    }

    func testOnlyMouseBurstsProduceSuggestions() throws {
        let config = try AeroSpaceConfig.parse("""
        [mode.main.binding]
        ctrl-alt-1 = 'workspace 1'
        ctrl-alt-2 = 'workspace 2'
        ctrl-alt-3 = 'workspace 3'
        """)
        let resolver = ActionResolver(modes: config)
        let suggestions = try replay().compactMap { verdict -> String? in
            guard case .mouse(let mouseSwitch) = verdict else { return nil }
            return resolver.suggestion(for: mouseSwitch)?.keys
        }
        XCTAssertEqual(suggestions, ["⌃⌥ 2", "⌃⌥ 3"])
    }
}
