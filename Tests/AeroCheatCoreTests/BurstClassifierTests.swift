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

    func testModeChangeAloneIsNotAnAction() {
        XCTAssertEqual(classify([(1, .modeChanged(mode: "main"))], input: clicked), [.ignored(.noWorkspaceChange)])
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

    // MARK: key after click

    func testKeyAfterTheClickIsNotAMouseSwitch() {
        // The live Cmd-Tab shape: a click 0.6 s earlier, a key 75 ms earlier.
        let input = InputRecency(sinceLeftMouseDown: 0.601, sinceLeftMouseUp: 0.600, sinceKeyDown: 0.075, sinceFlagsChanged: 0.008)
        XCTAssertEqual(classify(switchEvents(at: 1, from: "1", to: "2"), input: input), [.ignored(.keyAfterClick)])
    }

    func testModifierAfterTheClickAloneIsEnough() {
        let input = InputRecency(sinceLeftMouseDown: 0.3, sinceLeftMouseUp: 0.3, sinceFlagsChanged: 0.1)
        XCTAssertEqual(classify(switchEvents(at: 1, from: "1", to: "2"), input: input), [.ignored(.keyAfterClick)])
    }

    func testKeyBeforeTheClickDoesNotMatter() {
        // Mission Control opened with the keyboard three seconds before the click.
        let input = InputRecency(sinceLeftMouseDown: 0.16, sinceLeftMouseUp: 0.15, sinceKeyDown: 3.2, sinceFlagsChanged: 3.2)
        XCTAssertEqual(classify(switchEvents(at: 1, from: "2", to: "1"), input: input), [.mouse(MouseSwitch(from: "2", to: "1"))])
    }

    func testKeyWithoutRecentClickStaysNoRecentClick() {
        let input = InputRecency(sinceLeftMouseDown: 61.8, sinceLeftMouseUp: 61.7, sinceKeyDown: 0.09)
        XCTAssertEqual(classify(switchEvents(at: 1, from: "2", to: "3"), input: input), [.ignored(.noRecentClick)])
    }

    // MARK: same-workspace focus

    private func focus(at t: TimeInterval, _ windowId: Int, _ workspace: String = "1") -> (TimeInterval, AeroEvent) {
        (t, .focusChanged(windowId: windowId, workspace: workspace))
    }

    /// Establishes the baseline with one burst, then classifies the second.
    private func classifyFocus(_ second: [(TimeInterval, AeroEvent)], input: InputRecency, baseline: [(TimeInterval, AeroEvent)]? = nil) -> BurstVerdict? {
        var classifier = BurstClassifier()
        for (time, event) in baseline ?? [focus(at: 0, 1)] { _ = classifier.ingest(event, at: time, input: idle) }
        _ = classifier.flush()
        for (time, event) in second { _ = classifier.ingest(event, at: time, input: input) }
        return classifier.flush()
    }

    func testClickedFocusChangeIsAFocusCandidate() {
        let pointer = CGPoint(x: 600, y: 400)
        let input = InputRecency(sinceLeftMouseDown: 0.45, sinceLeftMouseUp: 0.403, pointer: pointer)
        XCTAssertEqual(
            classifyFocus([focus(at: 5, 2)], input: input),
            .mouseFocus(FocusSwitch(windowId: 2, workspace: "1", previousWindowId: 1, pointer: pointer))
        )
    }

    func testFocusChangeWithoutClickIsIgnored() {
        XCTAssertEqual(classifyFocus([focus(at: 5, 2)], input: idle), .ignored(.noRecentClick))
    }

    func testFocusChangeAfterKeyIsIgnored() {
        let input = InputRecency(sinceLeftMouseDown: 0.5, sinceLeftMouseUp: 0.5, sinceKeyDown: 0.05)
        XCTAssertEqual(classifyFocus([focus(at: 5, 2)], input: input), .ignored(.keyAfterClick))
    }

    func testFocusChangeWithBindingIsKeyboard() {
        let second: [(TimeInterval, AeroEvent)] = [(5, .bindingTriggered(binding: "ctrl-alt-l", mode: "main")), focus(at: 5.03, 2)]
        XCTAssertEqual(classifyFocus(second, input: clicked), .keyboard(binding: "ctrl-alt-l"))
    }

    func testFirstFocusEventHasNoBaseline() {
        var classifier = BurstClassifier()
        _ = classifier.ingest(.focusChanged(windowId: 2, workspace: "1"), at: 1, input: clicked)
        XCTAssertEqual(classifier.flush(), .ignored(.noFocusBaseline))
    }

    func testNewWindowFromAnEmptyWorkspaceHasNoBaseline() {
        var classifier = BurstClassifier()
        _ = classifier.ingest(.focusedWorkspaceChanged(prev: "1", workspace: "2"), at: 0, input: idle)
        _ = classifier.ingest(.focusChanged(windowId: 5, workspace: "2"), at: 6, input: clicked)
        XCTAssertEqual(classifier.flush(), .ignored(.noFocusBaseline))
    }

    func testFocusBouncingBackToTheSameWindowIsIgnored() {
        XCTAssertEqual(classifyFocus([focus(at: 5, 2), focus(at: 5.04, 1)], input: clicked), .ignored(.noFocusChange))
    }

    func testFocusOnNoWindowIsIgnored() {
        XCTAssertEqual(classifyFocus([(5, .focusChanged(windowId: 0, workspace: "1"))], input: clicked), .ignored(.noFocusChange))
    }

    func testFocusBurstUsesTheFinalWindow() {
        let verdict = classifyFocus([focus(at: 5, 2), focus(at: 5.04, 3)], input: clicked)
        XCTAssertEqual(verdict, .mouseFocus(FocusSwitch(windowId: 3, workspace: "1", previousWindowId: 1)))
    }

    func testBaselineFollowsKeyboardAndWorkspaceBursts() {
        var classifier = BurstClassifier()
        // Window 1 on workspace 1, then ctrl-alt-2 moves focus to window 7 on workspace 2 (the keyboard burst updates the baseline).
        _ = classifier.ingest(.focusChanged(windowId: 1, workspace: "1"), at: 0, input: idle)
        _ = classifier.ingest(.bindingTriggered(binding: "ctrl-alt-2", mode: "main"), at: 2, input: idle)
        _ = classifier.ingest(.focusChanged(windowId: 7, workspace: "2"), at: 2.03, input: idle)
        _ = classifier.ingest(.focusedWorkspaceChanged(prev: "1", workspace: "2"), at: 2.031, input: idle)
        // A click then moves focus within workspace 2.
        _ = classifier.ingest(.focusChanged(windowId: 8, workspace: "2"), at: 6, input: clicked)
        XCTAssertEqual(classifier.flush(), .mouseFocus(FocusSwitch(windowId: 8, workspace: "2", previousWindowId: 7)))
    }

    func testFocusChangeAcrossWorkspacesWithoutAWorkspaceEventHasNoBaseline() {
        XCTAssertEqual(classifyFocus([focus(at: 5, 9, "4")], input: clicked), .ignored(.noFocusBaseline))
    }

    func testFocusCandidateInNonMainModeIsIgnored() {
        let second: [(TimeInterval, AeroEvent)] = [(4.95, .modeChanged(mode: "service")), focus(at: 5, 2)]
        XCTAssertEqual(classifyFocus(second, input: clicked), .ignored(.modeNotMain))
    }
}
