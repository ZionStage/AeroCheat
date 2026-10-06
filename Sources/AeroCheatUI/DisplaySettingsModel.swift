import AeroCheatCore
import Combine
import Foundation

/// The live settings: the settings window edits `settings`, every change is clamped, saved and handed to the
/// observers (the active-mode controller), so it applies without a restart. Main thread only.
public final class DisplaySettingsModel: ObservableObject {
    @Published private var current: DisplaySettings

    /// Assigning clamps the value, saves it and notifies the observers, once, and only if it changed.
    public var settings: DisplaySettings {
        get { current }
        set {
            let clamped = newValue.normalized()
            guard clamped != current else { return }
            current = clamped
            storage?.save(clamped)
            observers.forEach { $0(clamped) }
        }
    }

    private let storage: DisplaySettingsStorage?
    private var observers: [(DisplaySettings) -> Void] = []

    /// Starts from what `storage` holds and saves every change back.
    public init(storage: DisplaySettingsStorage = DisplaySettingsStorage()) {
        self.storage = storage
        current = storage.load()
    }

    /// Never reads or writes `UserDefaults`: demo mode, which must not touch the user's preferences.
    public init(inMemory settings: DisplaySettings) {
        storage = nil
        current = settings.normalized()
    }

    /// `observer` is called after each change, not for the current value.
    public func addObserver(_ observer: @escaping (DisplaySettings) -> Void) {
        observers.append(observer)
    }

    public func resetToDefaults() {
        settings = DisplaySettings()
        storage?.clear()
    }
}
