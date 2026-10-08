import AeroCheatCore
import AeroCheatUI
import AppKit

/// Wires the AeroSpace event stream to the classifier, the suggestion policy and the toast.
/// Main queue only.
final class ActiveModeController {
    static let defaultsKey = "activeModeEnabled"
    /// Events this soon after our own toast are dropped (binding presses and display changes excepted): the toast must not feed itself.
    /// It only needs to cover the settling after the toast appears, so it stays far below the shortest
    /// configurable display duration (`DisplaySettings.durationRange`).
    private static let selfFeedbackGuard: TimeInterval = 0.5
    /// How often the notification and Dock windows on screen are looked up while active mode is on. A banner stays up for
    /// seconds, so a couple of looks per second are enough, and the probe thins them out when the machine is idle.
    private static let notificationPollInterval: TimeInterval = 0.5

    /// `nil` keeps the choice in memory only (demo mode must not touch the user's preferences).
    private let defaults: UserDefaults?
    private var enabledInMemory = true
    private let settings: DisplaySettingsModel
    private let source: AeroEventSource
    private let inputProbe: () -> InputRecency
    /// `nil` (demo mode) looks at no window and so never recognises a notification or Dock click, nor an ignored app.
    private let windowProbe: (() -> [ScreenWindow])?
    private let appProbe: ((Int) -> AppIdentity?)?
    private var notifications = ScreenZoneHitTest(zone: .notifications)
    private var dock = ScreenZoneHitTest(zone: .dock)
    private var notificationTimer: DispatchSourceTimer?
    private let toast = ToastPanel()
    private var classifier = BurstClassifier()
    private var policy: SuggestionPolicy
    private var resolver = ActionResolver(modes: [])
    private var settleWork: DispatchWorkItem?
    private var toastShownAt: TimeInterval = -.infinity
    /// Bumped on shutdown so a layout query still running is dropped.
    private var focusQueryGeneration = 0

    private(set) var lastSuggestion: Suggestion?
    /// Called for every shortcut press AeroSpace reports, with the binding as written and its mode.
    var onBindingTriggered: ((_ binding: String, _ mode: String) -> Void)?

    var isEnabled: Bool { defaults?.bool(forKey: Self.defaultsKey) ?? enabledInMemory }
    var streamStatus: AeroSpaceEventStream.Status { source.status }
    var snoozedUntil: Date? { policy.isSnoozed ? policy.snoozedUntil : nil }

    init(
        defaults: UserDefaults? = .standard,
        settings: DisplaySettingsModel,
        source: AeroEventSource = AeroSpaceEventStream(),
        inputProbe: @escaping () -> InputRecency = MouseInputProbe.recency,
        windowProbe: (() -> [ScreenWindow])? = ScreenWindowProbe.windows,
        appProbe: ((Int) -> AppIdentity?)? = ScreenWindowProbe.app(ofWindow:)
    ) {
        self.defaults = defaults
        self.settings = settings
        policy = SuggestionPolicy(limits: settings.settings.policyLimits)
        self.source = source
        self.inputProbe = inputProbe
        self.windowProbe = windowProbe
        self.appProbe = appProbe
        source.onEvent = { [weak self] in self?.handle($0) }
        // The delays apply to the next suggestion; what the policy remembers stays.
        settings.addObserver { [weak self] in self?.policy.limits = $0.policyLimits }
    }

    func startIfEnabled() {
        if isEnabled { start() }
    }

    func setEnabled(_ enabled: Bool) {
        enabledInMemory = enabled
        defaults?.set(enabled, forKey: Self.defaultsKey)
        if enabled {
            // A demo replay starts from a clean slate, or the policy would still remember the last run.
            if defaults == nil { policy = SuggestionPolicy(limits: settings.settings.policyLimits); lastSuggestion = nil }
            start()
        } else {
            shutdown()
        }
    }

    private func start() {
        source.start()
        startNotificationPolling()
    }

    func shutdown() {
        source.stop()
        stopNotificationPolling()
        focusQueryGeneration += 1
        settleWork?.cancel()
        _ = classifier.flush()
        classifier.forgetBaselines()
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
        if case .bindingTriggered(let binding, let mode) = event { onBindingTriggered?(binding, mode) }
        let now = ProcessInfo.processInfo.systemUptime
        if now - toastShownAt < Self.selfFeedbackGuard {
            switch event {
            case .bindingTriggered, .focusedMonitorChanged: break
            case .focusChanged, .focusedWorkspaceChanged: classifier.forgetFocus(); return
            default: return
            }
        }
        // Sampled when the event arrives, 1–3 ms after the fact, so a click still reads as recent.
        var input = inputProbe()
        if let windowProbe, input.sinceLastClick < classifier.mouseWindow {
            // The banner may already be gone, so it is also looked up in what the poll remembers.
            observeZones(windowProbe(), at: now)
            input.onNotification = notifications.isOver(input.pointer, at: now)
            input.onDock = settings.settings.ignoreDock && dock.isOver(input.pointer, at: now)
        }
        if let verdict = classifier.ingest(event, at: now, input: input) {
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

    private func startNotificationPolling() {
        guard let windowProbe, notificationTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + Self.notificationPollInterval, repeating: Self.notificationPollInterval, leeway: .milliseconds(250))
        timer.setEventHandler { [weak self] in
            self?.observeZones(windowProbe(), at: ProcessInfo.processInfo.systemUptime)
        }
        timer.resume()
        notificationTimer = timer
    }

    private func stopNotificationPolling() {
        notificationTimer?.cancel()
        notificationTimer = nil
        notifications.reset()
        dock.reset()
    }

    private func observeZones(_ windows: [ScreenWindow], at time: TimeInterval) {
        notifications.observe(windows, at: time)
        dock.observe(windows, at: time)
    }

    /// Focus landed on a window of an application the settings ignore.
    private func landedOnIgnoredApp(_ windowId: Int?) -> Bool {
        guard let appProbe, let windowId, !settings.settings.ignoredApps.isEmpty else { return false }
        return settings.settings.ignores(appProbe(windowId))
    }

    private func handle(_ verdict: BurstVerdict) {
        switch verdict {
        case .keyboard(let binding):
            policy.recordKeyboard(binding: binding)
        case .mouse(let mouseSwitch):
            guard !landedOnIgnoredApp(classifier.focusedWindowId), let suggestion = resolver.suggestion(for: mouseSwitch) else { return }
            present(suggestion)
        case .mouseMove(let move):
            guard !landedOnIgnoredApp(move.windowId), let suggestion = resolver.suggestion(for: move) else { return }
            present(suggestion)
        case .mouseFocus(let focus):
            guard !landedOnIgnoredApp(focus.windowId) else { return }
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
        // A kind switched off in the settings is checked before the policy, so it uses up no delay.
        guard settings.settings.isEnabled(suggestion.kind), policy.consider(suggestion) == .show else { return }
        lastSuggestion = suggestion
        toastShownAt = ProcessInfo.processInfo.systemUptime
        toast.show(suggestion, settings: settings.settings)
    }
}
