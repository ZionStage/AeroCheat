/// Where the "Launch at Login" registration stands, independent of ServiceManagement so the mapping below
/// stays testable.
public enum LoginItemStatus: Equatable {
    case notRegistered
    case enabled
    /// Registered, but the user still has to allow it in System Settings > Login Items.
    case requiresApproval
    /// The system cannot find the app (moved or damaged bundle).
    case notFound
    /// Not running from an `.app` bundle (for example `swift run`): there is nothing to register.
    case notInBundle
}

/// How the "Launch at Login" menu item and the line under it should look.
public struct LoginItemMenuState: Equatable {
    public var isChecked: Bool
    public var isEnabled: Bool
    /// Explanation shown in a disabled line under the item; nil hides the line.
    public var detail: String?
    /// Whether to offer a shortcut to System Settings > Login Items.
    public var offersSettings: Bool

    public init(status: LoginItemStatus) {
        switch status {
        case .enabled:
            self.init(isChecked: true, isEnabled: true, detail: nil, offersSettings: false)
        case .notRegistered:
            self.init(isChecked: false, isEnabled: true, detail: nil, offersSettings: false)
        case .requiresApproval:
            self.init(isChecked: false, isEnabled: true,
                      detail: "Waiting for approval in System Settings > Login Items", offersSettings: true)
        case .notFound:
            self.init(isChecked: false, isEnabled: true,
                      detail: "macOS cannot find the app: move it to Applications and relaunch", offersSettings: false)
        case .notInBundle:
            self.init(isChecked: false, isEnabled: false,
                      detail: "Only available in the packaged AeroCheat.app", offersSettings: false)
        }
    }

    private init(isChecked: Bool, isEnabled: Bool, detail: String?, offersSettings: Bool) {
        self.isChecked = isChecked
        self.isEnabled = isEnabled
        self.detail = detail
        self.offersSettings = offersSettings
    }
}
