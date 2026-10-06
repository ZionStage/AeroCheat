import XCTest
@testable import AeroCheatCore

final class BurstClassifierTests: XCTestCase {
    private let clicked = InputRecency(sinceLeftMouseDown: 0.2, sinceLeftMouseUp: 0.15)
    private let idle = InputRecency(sinceLeftMouseDown: 40, sinceLeftMouseUp: 40)

    private func classify(_ events: [(TimeInterval, AeroEvent)], input: InputRecency) -> [BurstVerdict] {
        var classifier = BurstClassifier()
        var verdicts: [BurstVerdict] = []
        for (time, event) in events {
            if let verdict = classifier.ingest(event, at: time, input: input) { verdicts.append(verdict) }
        }
        if let verdict = classifier.flush() { verdicts.append(verdict) }
        return verdicts
    }

    private func switchEvents(at t: TimeInterval, from: String, to: String) -> [(TimeInterval, AeroEvent)] {
        [(t, .focusChanged(windowId: 1, workspace: to)), (t + 0.001, .focusedWorkspaceChanged(prev: from, workspace: to))]
    }

    func testBurstWithBindingIsKeyboard() {
        let events: [(TimeInterval, AeroEvent)] = [(1.0, .bindingTriggered(binding: "ctrl-alt-3", mode: "main"))]
            + switchEvents(at: 1.03, from: "1", to: "3")
        XCTAssertEqual(classify(events, input: idle), [.keyboard(binding: "ctrl-alt-3")])
    }

    func testKeyboardWinsEvenWithRecentClick() {
        let events: [(TimeInterval, AeroEvent)] = [(1.0, .bindingTriggered(binding: "ctrl-alt-3", mode: "main"))]
            + switchEvents(at: 1.03, from: "1", to: "3")
        XCTAssertEqual(classify(events, input: clicked), [.keyboard(binding: "ctrl-alt-3")])
    }

    func testClickedSwitchIsMouse() {
        XCTAssertEqual(
            classify(switchEvents(at: 1, from: "2", to: "4"), input: clicked),
            [.mouse(MouseSwitch(from: "2", to: "4"))]
        )
    }

    func testSwitchWithoutRecentClickIsIgnored() {
        XCTAssertEqual(classify(switchEvents(at: 1, from: "2", to: "3"), input: idle), [.ignored(.noRecentClick)])
    }

    func testClickRecencyBoundary() {
        let stale = InputRecency(sinceLeftMouseDown: 0.9, sinceLeftMouseUp: 0.85)
        XCTAssertEqual(classify(switchEvents(at: 1, from: "2", to: "3"), input: stale), [.ignored(.noRecentClick)])
    }

    func testBounceWithoutBindingIsNoise() {
        let events = switchEvents(at: 1.00, from: "3", to: "1") + switchEvents(at: 1.04, from: "1", to: "3")
        XCTAssertEqual(classify(events, input: clicked), [.ignored(.bounce)])
    }

    func testBounceInsideKeyboardBurstIsOneKeyboardBurst() {
        let events: [(TimeInterval, AeroEvent)] = [(1.0, .bindingTriggered(binding: "ctrl-alt-1", mode: "main"))]
            + switchEvents(at: 1.04, from: "3", to: "1")
            + switchEvents(at: 1.08, from: "1", to: "3")
            + switchEvents(at: 1.12, from: "3", to: "1")
        XCTAssertEqual(classify(events, input: idle), [.keyboard(binding: "ctrl-alt-1")])
    }

    func testFocusOnlyBurstIsIgnored() {
        XCTAssertEqual(
            classify([(1, .focusChanged(windowId: 5, workspace: "2"))], input: clicked),
            [.ignored(.noWorkspaceChange)]
        )
    }

    func testInitialStateWithSameWorkspaceIsNotAnAction() {
        XCTAssertEqual(
            classify(switchEvents(at: 1, from: "2", to: "2"), input: clicked),
            [.ignored(.noWorkspaceChange)]
        )
    }

    func testEventsFurtherApartThanSettleFormSeparateBursts() {
        let events: [(TimeInterval, AeroEvent)] = [(1.0, .bindingTriggered(binding: "ctrl-alt-2", mode: "main"))]
            + switchEvents(at: 1.03, from: "1", to: "2")
            + switchEvents(at: 1.5, from: "2", to: "3")
        XCTAssertEqual(
            classify(events, input: clicked),
            [.keyboard(binding: "ctrl-alt-2"), .mouse(MouseSwitch(from: "2", to: "3"))]
        )
    }

    func testNonMainModeIsIgnored() {
        let events: [(TimeInterval, AeroEvent)] = [(0.95, .modeChanged(mode: "service"))]
            + switchEvents(at: 1, from: "1", to: "2")
        XCTAssertEqual(classify(events, input: clicked), [.ignored(.modeNotMain)])
    }

    func testReturningToThePreviousWorkspaceIsFlagged() {
        var classifier = BurstClassifier()
        _ = classifier.ingest(.focusedWorkspaceChanged(prev: "1", workspace: "2"), at: 1, input: clicked)
        _ = classifier.ingest(.focusedWorkspaceChanged(prev: "2", workspace: "1"), at: 5, input: clicked)
        XCTAssertEqual(classifier.flush(), .mouse(MouseSwitch(from: "2", to: "1", returnsToPrevious: true)))
    }

    func testKeyboardSwitchCountsAsPreviousWorkspace() {
        var classifier = BurstClassifier()
        _ = classifier.ingest(.bindingTriggered(binding: "ctrl-alt-2", mode: "main"), at: 1, input: idle)
        _ = classifier.ingest(.focusedWorkspaceChanged(prev: "1", workspace: "2"), at: 1.03, input: idle)
        _ = classifier.ingest(.focusedWorkspaceChanged(prev: "2", workspace: "1"), at: 5, input: clicked)
        XCTAssertEqual(classifier.flush(), .mouse(MouseSwitch(from: "2", to: "1", returnsToPrevious: true)))
    }
}
