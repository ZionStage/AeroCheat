import AeroCheatCore
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var hotkey: GlobalHotkey?
    private let model = CheatsheetModel(result: AeroSpaceConfigLoader.load())
    private let activeMode = ActiveModeController()
    private let activeToggle = NSMenuItem(title: "Active Mode", action: #selector(toggleActiveMode), keyEquivalent: "")
    private let activeStatus = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let lastSuggestion = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let snoozeItem = NSMenuItem(title: "", action: #selector(toggleSnooze), keyEquivalent: "")
    private lazy var panel: CheatsheetPanel = {
        let panel = CheatsheetPanel(model: model)
        panel.onDismiss = { [weak self] in self?.hidePanel() }
        return panel
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        hotkey = GlobalHotkey(keyCode: HotkeyConfig.keyCode, modifiers: HotkeyConfig.modifiers) { [weak self] in
            self?.togglePanel()
        }
        if hotkey == nil {
            NSLog("AeroCheat: could not register the global hotkey \(HotkeyConfig.display); use the menu bar item instead.")
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
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "AeroCheat")
        }

        let menu = NSMenu()
        let show = NSMenuItem(title: "Show Cheatsheet", action: #selector(showFromMenu), keyEquivalent: "")
        show.target = self
        menu.addItem(show)
        let reload = NSMenuItem(title: "Reload AeroSpace Config", action: #selector(reloadConfig), keyEquivalent: "")
        reload.target = self
        menu.addItem(reload)
        let hint = NSMenuItem(title: hotkey == nil ? "Hotkey unavailable" : "Hotkey: \(HotkeyConfig.display)", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)
        menu.addItem(.separator())
        activeToggle.target = self
        activeStatus.isEnabled = false
        lastSuggestion.isEnabled = false
        snoozeItem.target = self
        [activeToggle, activeStatus, lastSuggestion, snoozeItem].forEach(menu.addItem)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit AeroCheat", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        menu.delegate = self
        statusItem.menu = menu
        refreshActiveModeItems()
    }

    func menuWillOpen(_ menu: NSMenu) { refreshActiveModeItems() }

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
        guard activeMode.isEnabled else { return "Active mode is off" }
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

    @objc private func toggleSnooze() {
        if activeMode.snoozedUntil == nil { activeMode.snooze() } else { activeMode.resume() }
        refreshActiveModeItems()
    }

    @objc private func showFromMenu() { showPanel() }

    @objc private func reloadConfig() {
        model.reload()
        activeMode.updateConfig(model.result)
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
