import AeroCheatCore
import AppKit

/// Wires the AeroSpace event stream to the classifier, the suggestion policy and the toast.
/// Main queue only.
final class ActiveModeController {
    static let defaultsKey = "activeModeEnabled"
    /// Events this soon after our own toast are dropped (binding presses excepted): the toast must not feed itself.
    private static let selfFeedbackGuard: TimeInterval = 0.5

    private let defaults: UserDefaults
    private let stream = AeroSpaceEventStream()
    private let toast = ToastPanel()
    private var classifier = BurstClassifier()
    private var policy = SuggestionPolicy()
    private var resolver = ActionResolver(modes: [])
    private var settleWork: DispatchWorkItem?
    private var toastShownAt: TimeInterval = -.infinity

    private(set) var lastSuggestion: Suggestion?

    var isEnabled: Bool { defaults.bool(forKey: Self.defaultsKey) }
    var streamStatus: AeroSpaceEventStream.Status { stream.status }
    var snoozedUntil: Date? { policy.isSnoozed ? policy.snoozedUntil : nil }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        stream.onEvent = { [weak self] in self?.handle($0) }
    }

    func startIfEnabled() {
        if isEnabled { stream.start() }
    }

    func setEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Self.defaultsKey)
        if enabled {
            stream.start()
        } else {
            shutdown()
        }
    }

    func shutdown() {
        stream.stop()
        settleWork?.cancel()
        _ = classifier.flush()
        toast.dismiss()
    }

    func updateConfig(_ result: ConfigLoadResult) {
        if case .loaded(_, let modes) = result {
            resolver = ActionResolver(modes: modes)
        } else {
            resolver = ActionResolver(modes: [])
        }
    }

    func snooze() { policy.snooze(for: 3600) }
    func resume() { policy.resume() }

    private func handle(_ event: AeroEvent) {
        let now = ProcessInfo.processInfo.systemUptime
        if now - toastShownAt < Self.selfFeedbackGuard {
            guard case .bindingTriggered = event else { return }
        }
        // Sampled when the event arrives, 1–3 ms after the fact, so a click still reads as recent.
        if let verdict = classifier.ingest(event, at: now, input: MouseInputProbe.recency()) {
            handle(verdict)
        }
        settleWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, let verdict = self.classifier.flush() else { return }
            self.handle(verdict)
        }
        settleWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + classifier.settle + 0.01, execute: work)
    }

    private func handle(_ verdict: BurstVerdict) {
        switch verdict {
        case .keyboard(let binding):
            policy.recordKeyboard(binding: binding)
        case .mouse(let mouseSwitch):
            guard let suggestion = resolver.suggestion(for: mouseSwitch),
                  policy.consider(suggestion) == .show else { return }
            lastSuggestion = suggestion
            toastShownAt = ProcessInfo.processInfo.systemUptime
            toast.show(suggestion)
        case .ignored:
            break
        }
    }
}
