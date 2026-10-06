import AeroCheatCore
import AeroCheatUI
import AppKit
import SwiftUI

/// The settings window: `SettingsView` hosted in a plain titled window. Its Preview button shows the real
/// bubble on its own panel, so it never disturbs the active-mode toast.
final class SettingsWindow: NSWindow {
    private let model: DisplaySettingsModel
    private let previewToast = ToastPanel()

    init(model: DisplaySettingsModel) {
        self.model = model
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        title = "AeroCheat Settings"
        isReleasedWhenClosed = false
        contentView = NSHostingView(rootView: SettingsView(model: model, onPreview: { [weak self] in self?.preview() }))
        center()
    }

    func present() {
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
    }

    /// The demo script's bubble, with the settings as they are now.
    private func preview() {
        guard let suggestion = DemoScript.previewSuggestion() else { return }
        previewToast.show(suggestion, settings: model.settings)
    }
}
