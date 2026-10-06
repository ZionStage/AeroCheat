import AeroCheatCore
import Foundation

/// Plays `DemoScript` instead of the real AeroSpace stream (`AeroCheat --demo`). It starts no process, reads
/// no config and never talks to AeroSpace. The events go through the same controller path as real ones.
final class DemoEventSource: AeroEventSource {
    /// Time to get a look at the screen before the first scenario starts.
    private static let leadIn: TimeInterval = 1.5

    var onEvent: ((AeroEvent) -> Void)?
    private(set) var status: AeroSpaceEventStream.Status = .stopped
    /// The mouse state scripted for the event being delivered; the controller reads it instead of the hardware.
    private(set) var currentInput: InputRecency = .idle

    private let scenarios: [DemoScenario]
    private var generation = 0

    init(scenarios: [DemoScenario] = DemoScript.scenarios) {
        self.scenarios = scenarios
    }

    /// Starting again after `stop()` replays the script from the top.
    func start() {
        guard status == .stopped else { return }
        generation += 1
        status = .connected
        let gen = generation
        let items = DemoScript.timeline(of: scenarios)
        NSLog("AeroCheat demo: playing \(scenarios.count) scenarios (about \(Int((items.last?.at ?? 0).rounded(.up))) s). AeroSpace is not used.")
        for item in items {
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.leadIn + item.at) { [weak self] in
                guard let self, self.generation == gen else { return }
                if item.isFirstOfScenario {
                    let scenario = self.scenarios[item.scenarioIndex]
                    NSLog("AeroCheat demo \(item.scenarioIndex + 1)/\(self.scenarios.count): \(scenario.name)")
                }
                self.currentInput = item.input
                self.onEvent?(item.event)
            }
        }
        // Past the last event and its settle delay, so the final bubble is already up.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.leadIn + (items.last?.at ?? 0) + 1) { [weak self] in
            guard let self, self.generation == gen else { return }
            NSLog("AeroCheat demo: finished. Untick and tick Active Mode in the menu to replay, or quit.")
        }
    }

    func stop() {
        generation += 1
        status = .stopped
        currentInput = .idle
    }
}
