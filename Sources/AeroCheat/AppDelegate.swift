import AeroCheatCore
import AeroCheatUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var hotkey: GlobalHotkey?
    private let demo: Bool
    private let model: CheatsheetModel
    private let activeMode: ActiveModeController
    private let settings: DisplaySettingsModel
    private let configSource: ConfigSourceModel
    private let hotkeySettings: HotkeySettingsModel
    /// `nil` in demo mode: presses are counted in memory only.
    private let usageStorage: ShortcutUsageStorage?
    private let hotkeyHint = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let activeToggle = NSMenuItem(title: "Active Mode", action: #selector(toggleActiveMode), keyEquivalent: "")
    private let activeStatus = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let lastSuggestion = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let snoozeItem = NSMenuItem(title: "", action: #selector(toggleSnooze), keyEquivalent: "")
    private let loginItem = LoginItemController()
    private let loginToggle = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
    private let loginStatus = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let loginSettings = NSMenuItem(title: "Open Login Items Settings…", action: #selector(openLoginItemsSettings), keyEquivalent: "")
    private lazy var settingsWindow = SettingsWindow(model: settings, configSource: configSource, hotkey: hotkeySettings)
    private lazy var panel: CheatsheetPanel = {
        let panel = CheatsheetPanel(model: model)
        panel.onDismiss = { [weak self] in self?.hidePanel() }
        return panel
    }()

    /// In demo mode nothing real is read or started: the sample config replaces `~/.aerospace.toml` and the
    /// scripted events replace `aerospace subscribe`.
    init(demo: Bool = false) {
        self.demo = demo
        if demo {
            let source = DemoEventSource()
            // Demo shows the user's saved look but never saves a change.
            settings = DisplaySettingsModel(inMemory: DisplaySettingsStorage().load())
            // The path setting is edited in memory and ignored: the sample config always stands in.
            configSource = ConfigSourceModel(storage: nil, loader: { _ in DemoScript.sampleConfigResult() })
            activeMode = ActiveModeController(defaults: nil, settings: settings, source: source, inputProbe: { source.currentInput }, windowProbe: nil, appProbe: nil)
            hotkeySettings = HotkeySettingsModel(storage: nil)
            usageStorage = nil
        } else {
            configSource = ConfigSourceModel()
            settings = DisplaySettingsModel()
            activeMode = ActiveModeController(settings: settings)
            hotkeySettings = HotkeySettingsModel()
            usageStorage = ShortcutUsageStorage()
        }
        model = CheatsheetModel(result: configSource.result)
        model.hotkey = hotkeySettings.hotkey
        model.usage = usageStorage?.load() ?? ShortcutUsage()
        super.init()
        hotkeySettings.register = { [weak self] in self?.registerHotkey($0) ?? false }
        hotkeySettings.aeroSpaceModes = { [weak self] in
            guard case .loaded(_, let modes) = self?.configSource.result else { return [] }
            return modes
        }
        hotkeySettings.addObserver { [weak self] in
            self?.model.hotkey = $0
            self?.refreshHotkeyHint()
        }
        activeMode.onBindingTriggered = { [weak self] binding, mode in
            guard let self else { return }
            self.model.usage.record(binding: binding, mode: mode)
            self.usageStorage?.save(self.model.usage)
        }
        // Every load (new path, menu reload) reaches the panel and the binding index of the active mode.
        configSource.addObserver { [weak self] result in
            self?.model.result = result
            self?.activeMode.updateConfig(result)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        hotkey = makeHotkey(hotkeySettings.hotkey)
        if hotkey == nil {
            NSLog("AeroCheat: could not register the global hotkey \(hotkeySettings.hotkey.display); use the menu bar item instead.")
        }
        configureStatusItem()
        activeMode.updateConfig(model.result)
        activeMode.startIfEnabled()
    }

    func applicationWillTerminate(_ notification: Notification) {
        activeMode.shutdown()
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            // The logo is embedded in the binary; the SF Symbol only covers a decoding failure.
            let image = MenuBarLogo.makeImage() ?? NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil)
            image?.accessibilityDescription = "AeroCheat"
            button.image = image
        }

        let menu = NSMenu()
        let show = NSMenuItem(title: "Show Cheatsheet", action: #selector(showFromMenu), keyEquivalent: "")
        show.target = self
        menu.addItem(show)
        let reload = NSMenuItem(title: "Reload AeroSpace Config", action: #selector(reloadConfig), keyEquivalent: "")
        reload.target = self
        menu.addItem(reload)
        hotkeyHint.isEnabled = false
        menu.addItem(hotkeyHint)
        menu.addItem(.separator())
        activeToggle.target = self
        activeStatus.isEnabled = false
        lastSuggestion.isEnabled = false
        snoozeItem.target = self
        [activeToggle, activeStatus, lastSuggestion, snoozeItem].forEach(menu.addItem)
        menu.addItem(.separator())
        loginToggle.target = self
        loginStatus.isEnabled = false
        loginSettings.target = self
        [loginToggle, loginStatus, loginSettings].forEach(menu.addItem)
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        let quit = NSMenuItem(title: "Quit AeroCheat", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        menu.delegate = self
        statusItem.menu = menu
        refreshHotkeyHint()
        refreshActiveModeItems()
        refreshLoginItems()
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshActiveModeItems()
        refreshLoginItems()
    }

    private func refreshHotkeyHint() {
        hotkeyHint.title = hotkey == nil ? "Hotkey unavailable" : "Hotkey: \(hotkeySettings.hotkey.display)"
    }

    private func makeHotkey(_ combination: Hotkey) -> GlobalHotkey? {
        GlobalHotkey(combination) { [weak self] in self?.togglePanel() }
    }

    /// Swaps the registered hotkey for `new`. When macOS refuses it, the current one is registered again.
    private func registerHotkey(_ new: Hotkey) -> Bool {
        hotkey = nil
        if let registered = makeHotkey(new) {
            hotkey = registered
            return true
        }
        hotkey = makeHotkey(hotkeySettings.hotkey)
        refreshHotkeyHint()
        return false
    }

    private func refreshLoginItems() {
        let state = LoginItemMenuState(status: loginItem.status)
        loginToggle.state = state.isChecked ? .on : .off
        loginToggle.isEnabled = state.isEnabled
        let detail = loginItem.lastError ?? state.detail
        loginStatus.title = detail ?? ""
        loginStatus.isHidden = detail == nil
        loginSettings.isHidden = !state.offersSettings
    }

    private func refreshActiveModeItems() {
        activeToggle.state = activeMode.isEnabled ? .on : .off
        activeStatus.title = activeStatusText()
        lastSuggestion.title = "Last suggestion: " + (activeMode.lastSuggestion?.summary ?? "none yet")
        if let until = activeMode.snoozedUntil {
            snoozeItem.title = "Resume Suggestions (snoozed until \(until.formatted(date: .omitted, time: .shortened)))"
        } else {
            snoozeItem.title = "Snooze Suggestions for 1 Hour"
        }
        snoozeItem.isEnabled = activeMode.isEnabled
    }

    private func activeStatusText() -> String {
        guard activeMode.isEnabled else { return demo ? "Demo mode: tick Active Mode to play the script" : "Active mode is off" }
        if demo { return "Demo mode: playing fixture events, AeroSpace is not used" }
        switch activeMode.streamStatus {
        case .stopped, .connecting: return "Connecting to AeroSpace…"
        case .connected: return "Watching for mouse workspace switches"
        case .notInstalled: return "AeroSpace not found (looked in /opt/homebrew/bin, /usr/local/bin, PATH)"
        case .tooOld(let version): return "AeroSpace \(version) is too old: active mode needs 0.21 or newer"
        case .notRunning: return "AeroSpace is not running, retrying…"
        }
    }

    @objc private func toggleActiveMode() {
        activeMode.setEnabled(!activeMode.isEnabled)
        refreshActiveModeItems()
    }

    @objc private func toggleLaunchAtLogin() {
        loginItem.toggle()
        refreshLoginItems()
    }

    @objc private func openLoginItemsSettings() { loginItem.openSystemSettings() }

    @objc private func toggleSnooze() {
        if activeMode.snoozedUntil == nil { activeMode.snooze() } else { activeMode.resume() }
        refreshActiveModeItems()
    }

    @objc private func showSettings() { settingsWindow.present() }

    @objc private func showFromMenu() { showPanel() }

    @objc private func reloadConfig() {
        configSource.reload()
    }

    private func togglePanel() {
        panel.isVisible ? hidePanel() : showPanel()
    }

    private func showPanel() {
        model.query = ""
        model.focusToken += 1
        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            let size = panel.frame.size
            panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2 + frame.height * 0.1))
        }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func hidePanel() {
        panel.orderOut(nil)
    }
}
