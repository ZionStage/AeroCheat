import XCTest
@testable import AeroCheatCore

/// Replays the demo script through the real classifier, resolver and policy, the way the app does, and checks
/// that every scenario does what it says. Time is simulated, so the 34 s script runs instantly.
final class DemoScriptTests: XCTestCase {
    private struct Outcome {
        let scenario: DemoScenario
        let expectation: DemoExpectation
        let hint: String?
    }

    private func play(_ scenarios: [DemoScenario]) throws -> [Outcome] {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var now = start
        var classifier = BurstClassifier()
        var policy = SuggestionPolicy(clock: { now })
        guard case .loaded(_, let modes) = DemoScript.sampleConfigResult() else { throw XCTSkip("sample config did not load") }
        let resolver = ActionResolver(modes: modes)

        var outcomes: [Outcome] = []
        var verdicts: [BurstVerdict] = []
        func close(after scenario: DemoScenario) {
            if let verdict = classifier.flush() { verdicts.append(verdict) }
            var expectation = DemoExpectation.silent("no verdict")
            var hint: String?
            for verdict in verdicts {
                switch verdict {
                case .keyboard(let binding):
                    policy.recordKeyboard(binding: binding)
                    expectation = .silent("keyboard")
                case .mouse(let mouseSwitch):
                    guard let suggestion = resolver.suggestion(for: mouseSwitch) else {
                        expectation = .silent("no binding")
                        continue
                    }
                    switch policy.consider(suggestion) {
                    case .show:
                        expectation = .bubble(keys: suggestion.keys)
                        hint = suggestion.hint
                    case .suppressed(let reason):
                        expectation = .silent("\(reason)")
                    }
                case .mouseFocus:
                    // Needs the layout probe, which the demo script does not simulate.
                    expectation = .silent("focus")
                case .mouseMove:
                    // The demo script has a single display, so no window is dragged to another one.
                    expectation = .silent("move")
                case .ignored(let reason):
                    expectation = .silent("\(reason)")
                }
            }
            verdicts = []
            outcomes.append(Outcome(scenario: scenario, expectation: expectation, hint: hint))
        }

        var current = -1
        for item in DemoScript.timeline(of: scenarios) {
            if item.scenarioIndex != current {
                if current >= 0 { close(after: scenarios[current]) }
                current = item.scenarioIndex
            }
            now = start.addingTimeInterval(item.at)
            if let verdict = classifier.ingest(item.event, at: item.at, input: item.input) { verdicts.append(verdict) }
        }
        if current >= 0 {
            now = now.addingTimeInterval(classifier.settle + 0.01)
            close(after: scenarios[current])
        }
        return outcomes
    }

    func testSampleConfigParsesAndHasTheBindingsTheScriptNeeds() throws {
        guard case .loaded(let path, let modes) = DemoScript.sampleConfigResult() else { return XCTFail("did not load") }
        XCTAssertEqual(path, DemoScript.sampleConfigPath)
        let resolver = ActionResolver(modes: modes)
        for workspace in ["1", "2", "3"] {
            XCTAssertNotNil(resolver.binding(for: .workspace(workspace)), "no binding for workspace \(workspace)")
        }
        XCTAssertNotNil(resolver.binding(for: .workspaceBackAndForth))
    }

    func testEveryScenarioDoesWhatItSays() throws {
        let outcomes = try play(DemoScript.scenarios)
        XCTAssertEqual(outcomes.count, DemoScript.scenarios.count)
        for outcome in outcomes {
            XCTAssertEqual(outcome.expectation, outcome.scenario.expectation, outcome.scenario.name)
        }
    }

    func testTimelineLaysScenariosEndToEnd() {
        let timeline = DemoScript.timeline()
        XCTAssertEqual(timeline.map(\.at), timeline.map(\.at).sorted())
        XCTAssertEqual(Set(timeline.map(\.scenarioIndex)).count, DemoScript.scenarios.count)
        XCTAssertEqual(timeline.filter(\.isFirstOfScenario).count, DemoScript.scenarios.count)
        XCTAssertEqual(timeline.first?.at ?? -1, DemoScript.scenarios[0].pause, accuracy: 0.0001)
    }

}
