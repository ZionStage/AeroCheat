import AeroCheatCore
import Combine
import Foundation

/// The live cheatsheet hotkey. The settings window records a new combination; it is checked, registered by
/// the app (`register`), saved and handed to the observers (menu, panel footer) at once, without a restart.
/// Main thread only.
public final class HotkeySettingsModel: ObservableObject {
    @Published public private(set) var hotkey: Hotkey
    /// Why the last recorded combination was refused; cleared by the next accepted one.
    @Published public private(set) var problem: String?

    /// Registers a combination system-wide in place of the current one; `false` when macOS refuses it, in which
    /// case the current one must stay registered. `nil` (tests) accepts everything.
    public var register: ((Hotkey) -> Bool)?
    /// The loaded AeroSpace bindings, so a combination AeroSpace already uses is refused.
    public var aeroSpaceModes: () -> [BindingMode] = { [] }

    private let storage: HotkeyStorage?
    private var observers: [(Hotkey) -> Void] = []

    /// `nil` storage never reads or writes `UserDefaults` (demo mode).
    public init(storage: HotkeyStorage? = HotkeyStorage()) {
        self.storage = storage
        hotkey = storage?.load() ?? .default
    }

    /// `observer` is called after each change, not for the current value.
    public func addObserver(_ observer: @escaping (Hotkey) -> Void) {
        observers.append(observer)
    }

    /// A key pressed while recording. Returns whether it became the hotkey.
    @discardableResult
    public func record(keyCode: UInt32, modifiers: Set<Modifier>) -> Bool {
        switch Hotkey.validate(keyCode: keyCode, modifiers: modifiers, modes: aeroSpaceModes()) {
        case .success(let new): return apply(new)
        case .failure(let reason):
            problem = reason.description
            return false
        }
    }

    public func resetToDefault() { apply(.default) }

    @discardableResult
    private func apply(_ new: Hotkey) -> Bool {
        guard new != hotkey else {
            problem = nil
            return true
        }
        if let register, !register(new) {
            problem = "macOS refused \(new.display): another app probably uses it."
            return false
        }
        hotkey = new
        problem = nil
        storage?.save(new)
        observers.forEach { $0(new) }
        return true
    }
}
