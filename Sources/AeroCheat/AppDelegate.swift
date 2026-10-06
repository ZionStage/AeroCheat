import AeroCheatCore
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotkey: GlobalHotkey?
    private let model = CheatsheetModel(result: AeroSpaceConfigLoader.load())
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
        let quit = NSMenuItem(title: "Quit AeroCheat", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        statusItem.menu = menu
    }

    @objc private func showFromMenu() { showPanel() }

    @objc private func reloadConfig() { model.reload() }

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
