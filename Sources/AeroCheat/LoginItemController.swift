import AeroCheatCore
import Foundation
import ServiceManagement

/// Registers and unregisters the app as a login item through `SMAppService.mainApp`. The status is always read
/// from the system, never cached, so the menu shows what the user sees in System Settings.
final class LoginItemController {
    /// Message of the last failed register or unregister, shown in the menu until the next attempt.
    private(set) var lastError: String?

    private var isInBundle: Bool {
        Bundle.main.bundleURL.pathExtension == "app" && Bundle.main.bundleIdentifier != nil
    }

    var status: LoginItemStatus {
        guard isInBundle else { return .notInBundle }
        switch SMAppService.mainApp.status {
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        case .notFound: return .notFound
        case .notRegistered: return .notRegistered
        @unknown default: return .notRegistered
        }
    }

    func toggle() {
        lastError = nil
        let service = SMAppService.mainApp
        do {
            switch status {
            case .enabled, .requiresApproval: try service.unregister()
            case .notRegistered, .notFound: try service.register()
            case .notInBundle: return
            }
        } catch {
            NSLog("AeroCheat: launch at login change failed: \(error.localizedDescription)")
            lastError = "Could not change the setting: \(error.localizedDescription)"
        }
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
