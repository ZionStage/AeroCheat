import AeroCheatCore
import AppKit

/// Wires the AeroSpace event stream to the classifier, the suggestion policy and the toast.
/// Main queue only.
final class ActiveModeController {
    static let defaultsKey = "activeModeEnabled"
    /// Events this soon after our own toast are dropped (binding presses excepted): the toast must not feed itself.
    /// It only needs to cover the settling after the toast appears, so it stays far below `BubbleStyle.duration`.
    private static let selfFeedbackGuard: TimeInterval = 0.5

    /// `nil` keeps the choice in memory only (demo mode must not touch the user's preferences).
    private let defaults: UserDefaults?
    private var enabledInMemory = true
    private let source: AeroEventSource
    private let inputProbe: () -> InputRecency
    private let toast = ToastPanel()
    private var classifier = BurstClassifier()
    private var policy = SuggestionPolicy()
    private var resolver = ActionResolver(modes: [])
    private var settleWork: DispatchWorkItem?
    private var toastShownAt: TimeInterval = -.infinity
    /// Bumped on shutdown so a layout query still running is dropped.
    private var focusQueryGeneration = 0

    private(set) var lastSuggestion: Suggestion?

    var isEnabled: Bool { defaults?.bool(forKey: Self.defaultsKey) ?? enabledInMemory }
    var streamStatus: AeroSpaceEventStream.Status { source.status }
    var snoozedUntil: Date? { policy.isSnoozed ? policy.snoozedUntil : nil }

    init(
        defaults: UserDefaults? = .standard,
        source: AeroEventSource = AeroSpaceEventStream(),
        inputProbe: @escaping () -> InputRecency = MouseInputProbe.recency
    ) {
        self.defaults = defaults
        self.source = source
        self.inputProbe = inputProbe
        source.onEvent = { [weak self] in self?.handle($0) }
    }

    func startIfEnabled() {
        if isEnabled { source.start() }
    }

    func setEnabled(_ enabled: Bool) {
        enabledInMemory = enabled
        defaults?.set(enabled, forKey: Self.defaultsKey)
        if enabled {
            // A demo replay starts from a clean slate, or the policy would still remember the last run.
            if defaults == nil { policy = SuggestionPolicy(); lastSuggestion = nil }
            source.start()
        } else {
            shutdown()
        }
    }

    func shutdown() {
        source.stop()
        focusQueryGeneration += 1
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
        if let verdict = classifier.ingest(event, at: now, input: inputProbe()) {
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
            guard let suggestion = resolver.suggestion(for: mouseSwitch) else { return }
            present(suggestion)
        case .mouseFocus(let focus):
            suggestFocus(focus)
        case .ignored:
            break
        }
    }

    /// A click moved focus within a workspace. The suggestion depends on the window's layout, which takes one
    /// read-only `aerospace list-windows` call, made off the main queue and only when the config has a focus binding.
    private func suggestFocus(_ focus: FocusSwitch) {
        guard resolver.hasFocusBindings, let binary = AeroSpaceEventStream.locateBinary() else { return }
        let generation = focusQueryGeneration
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let info = FocusedWindowProbe.info(ofWindow: focus.windowId, previousWindow: focus.previousWindowId, binary: binary)
            DispatchQueue.main.async {
                guard let self, self.focusQueryGeneration == generation, let info,
                      let suggestion = self.resolver.suggestion(for: focus, layout: info.layout, windowFrame: info.frame)
                else { return }
                self.present(suggestion)
            }
        }
    }

    private func present(_ suggestion: Suggestion) {
        guard policy.consider(suggestion) == .show else { return }
        lastSuggestion = suggestion
        toastShownAt = ProcessInfo.processInfo.systemUptime
        toast.show(suggestion)
    }
}
