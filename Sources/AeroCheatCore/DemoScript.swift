import Foundation

/// What a demo scenario is expected to do once it plays through the real classifier, resolver and policy.
public enum DemoExpectation: Equatable {
    /// The bubble appears with this shortcut (`Suggestion.keys`).
    case bubble(keys: String)
    /// No bubble, for the reason given.
    case silent(String)
}

/// One scripted event: it arrives `offset` seconds after the start of its scenario, with the mouse state
/// the classifier should see at that moment.
public struct DemoEvent: Equatable {
    public let offset: TimeInterval
    public let event: AeroEvent
    public let input: InputRecency

    public init(offset: TimeInterval, event: AeroEvent, input: InputRecency) {
        self.offset = offset
        self.event = event
        self.input = input
    }
}

/// A short burst of events and what should come of it.
public struct DemoScenario: Equatable {
    public let name: String
    /// Seconds of quiet between the end of the previous scenario and the start of this one.
    public let pause: TimeInterval
    public let events: [DemoEvent]
    public let expectation: DemoExpectation

    public init(name: String, pause: TimeInterval, events: [DemoEvent], expectation: DemoExpectation) {
        self.name = name
        self.pause = pause
        self.events = events
        self.expectation = expectation
    }
}

/// Fixture events for demo mode (`AeroCheat --demo`). Nothing here touches AeroSpace or the user's config:
/// the events are made up and `sampleConfig` stands in for `~/.aerospace.toml`.
///
/// To add a scenario, append one to `scenarios` using the helpers below; `DemoScriptTests` replays the whole
/// script through the real pipeline and fails if a scenario does not do what its `expectation` says.
public enum DemoScript {
    public static let sampleConfig = """
    # Sample AeroSpace config used by demo mode, in place of the user's own.
    [mode.main.binding]
    ctrl-alt-1 = 'workspace 1'
    ctrl-alt-2 = 'workspace 2'
    ctrl-alt-3 = 'workspace 3'
    ctrl-alt-tab = 'workspace-back-and-forth'
    ctrl-alt-h = 'focus left'
    ctrl-alt-l = 'focus right'
    """

    public static let sampleConfigPath = "demo sample config"

    /// The sample config as the cheatsheet and the resolver consume it.
    public static func sampleConfigResult() -> ConfigLoadResult {
        do {
            return .loaded(path: sampleConfigPath, modes: try AeroSpaceConfig.parse(sampleConfig))
        } catch {
            return .failed(path: sampleConfigPath, message: "\(error)")
        }
    }

    /// The suggestion of the settings window's Preview button: the sample config's workspace 2 binding, with
    /// the toggle-back hint, so the preview shows the whole bubble.
    public static func previewSuggestion() -> Suggestion? {
        guard case .loaded(_, let modes) = sampleConfigResult() else { return nil }
        return ActionResolver(modes: modes).suggestion(for: MouseSwitch(from: "1", to: "2", returnsToPrevious: true))
    }

    /// Played in order. The pauses keep clear of the policy limits on purpose: a bubble every 5 s at most
    /// and the same suggestion once per 30 s, so scenario 3 is rate limited and scenario 5 waits it out.
    public static let scenarios: [DemoScenario] = [
        DemoScenario(
            name: "Mouse switch to workspace 2: the bubble suggests ⌃⌥ 2",
            pause: 1,
            events: mouseSwitch(from: "1", to: "2"),
            expectation: .bubble(keys: "⌃⌥ 2")
        ),
        DemoScenario(
            name: "Keyboard switch back to workspace 1 (ctrl-alt-1): nothing shown",
            pause: 6,
            events: keyboardSwitch(binding: "ctrl-alt-1", from: "2", to: "1"),
            expectation: .silent("keyboard")
        ),
        DemoScenario(
            name: "Mouse switch to workspace 2 again, 10 s later: same suggestion, rate limited",
            pause: 4,
            events: mouseSwitch(from: "1", to: "2"),
            expectation: .silent("cooldown")
        ),
        DemoScenario(
            name: "Mouse switch to workspace 3: the bubble suggests ⌃⌥ 3",
            pause: 6,
            events: mouseSwitch(from: "2", to: "3"),
            expectation: .bubble(keys: "⌃⌥ 3")
        ),
        DemoScenario(
            name: "Mouse switch back to workspace 2, 30 s after the first: bubble with the toggle-back hint",
            pause: 17,
            events: mouseSwitch(from: "3", to: "2"),
            expectation: .bubble(keys: "⌃⌥ 2")
        ),
    ]

    // MARK: Scenario building blocks

    /// A click, then the workspace change AeroSpace reports for it, all within one burst.
    public static func mouseSwitch(from: String, to: String) -> [DemoEvent] {
        let click = InputRecency(sinceLeftMouseDown: 0.05, sinceLeftMouseUp: 0.03)
        return [
            DemoEvent(offset: 0, event: .focusChanged(windowId: 101, workspace: to), input: click),
            DemoEvent(offset: 0.02, event: .focusedWorkspaceChanged(prev: from, workspace: to), input: click),
        ]
    }

    /// A key binding: AeroSpace reports `binding-triggered` along with the change.
    public static func keyboardSwitch(binding: String, from: String, to: String) -> [DemoEvent] {
        [
            DemoEvent(offset: 0, event: .bindingTriggered(binding: binding, mode: "main"), input: .idle),
            DemoEvent(offset: 0.01, event: .focusedWorkspaceChanged(prev: from, workspace: to), input: .idle),
            DemoEvent(offset: 0.02, event: .focusChanged(windowId: 102, workspace: to), input: .idle),
        ]
    }

    // MARK: Timeline

    /// One event placed on the whole script's clock.
    public struct TimedEvent: Equatable {
        /// Seconds since the script started.
        public let at: TimeInterval
        public let scenarioIndex: Int
        public let isFirstOfScenario: Bool
        public let event: AeroEvent
        public let input: InputRecency
    }

    /// Lays the scenarios end to end: each starts `pause` seconds after the last event of the one before.
    public static func timeline(of scenarios: [DemoScenario] = DemoScript.scenarios) -> [TimedEvent] {
        var items: [TimedEvent] = []
        var clock: TimeInterval = 0
        for (index, scenario) in scenarios.enumerated() {
            clock += scenario.pause
            for (position, entry) in scenario.events.enumerated() {
                items.append(TimedEvent(
                    at: clock + entry.offset,
                    scenarioIndex: index,
                    isFirstOfScenario: position == 0,
                    event: entry.event,
                    input: entry.input
                ))
            }
            clock += scenario.events.map(\.offset).max() ?? 0
        }
        return items
    }
}
