import Foundation

/// The global shortcut that toggles the cheatsheet: a macOS virtual key code plus modifiers, also written as
/// an AeroSpace-style combo (`ctrl-alt-cmd-c`) so it is stored, shown and compared like a binding.
public struct Hotkey: Equatable {
    public let keyCode: UInt32
    public let combo: KeyCombo

    /// ⌃⌥⌘C: three modifiers plus a letter, clear of the usual AeroSpace bindings (alt-, alt-shift- or
    /// ctrl-alt- plus a key).
    public static let `default` = Hotkey(raw: "ctrl-alt-cmd-c")!

    /// `nil` when the key has no AeroSpace name in `keyNames` (a media key, a key of another layout...).
    public init?(keyCode: UInt32, modifiers: Set<Modifier>) {
        guard let name = Self.keyNames[keyCode] else { return nil }
        self.keyCode = keyCode
        combo = KeyCombo(raw: (modifiers.sorted().map(\.rawValue) + [name]).joined(separator: "-"))
    }

    /// Reads a stored combo; `nil` when its key is unknown.
    public init?(raw: String) {
        let combo = KeyCombo(raw: raw)
        guard let code = Self.keyNames.first(where: { $0.value == combo.key.lowercased() })?.key else { return nil }
        self.init(keyCode: code, modifiers: Set(combo.modifiers))
    }

    /// What is stored, e.g. `ctrl-alt-cmd-c`.
    public var raw: String { combo.canonical }
    public var modifiers: Set<Modifier> { Set(combo.modifiers) }
    /// Shown in the menu, the panel footer and the settings, e.g. `⌃⌥⌘C`.
    public var display: String { combo.modifierSymbols + combo.keyDisplay }

    /// macOS virtual key codes (ANSI layout, as in `Carbon.HIToolbox`) to AeroSpace key names.
    static let keyNames: [UInt32: String] = {
        var names: [UInt32: String] = [
            0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x", 8: "c", 9: "v", 11: "b", 12: "q",
            13: "w", 14: "e", 15: "r", 16: "y", 17: "t", 31: "o", 32: "u", 34: "i", 35: "p", 37: "l", 38: "j",
            40: "k", 45: "n", 46: "m",
            18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 25: "9", 26: "7", 28: "8", 29: "0",
            24: "equal", 27: "minus", 30: "rightsquarebracket", 33: "leftsquarebracket", 39: "quote",
            41: "semicolon", 42: "backslash", 43: "comma", 44: "slash", 47: "period", 50: "backtick",
            36: "enter", 48: "tab", 49: "space", 51: "backspace", 53: "esc", 117: "delete",
            123: "left", 124: "right", 125: "down", 126: "up",
        ]
        let functionKeys: [UInt32] = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, 105, 107, 113, 106, 64, 79, 80, 90]
        for (index, code) in functionKeys.enumerated() { names[code] = "f\(index + 1)" }
        return names
    }()
}

/// Why a recorded combination cannot become the hotkey.
public enum HotkeyProblem: Error, Equatable, CustomStringConvertible {
    case unsupportedKey
    case needsModifier
    case usedByMenu
    case reserved
    case boundInAeroSpace(command: String)

    public var description: String {
        switch self {
        case .unsupportedKey: return "This key cannot be used."
        case .needsModifier: return "Add at least one of ⌃, ⌥ or ⌘."
        case .usedByMenu: return "AeroCheat's menu already uses this combination."
        case .reserved: return "macOS or most apps already use this combination."
        case .boundInAeroSpace(let command): return "Your AeroSpace config binds it to “\(command)”."
        }
    }
}

extension Hotkey {
    /// The menu's key equivalents (Settings…, Quit).
    static let menuCombos: Set<String> = ["cmd-comma", "cmd-q"]

    /// Combinations macOS or nearly every app keeps for itself. Not exhaustive: the system refuses others at
    /// registration.
    static let reservedCombos: Set<String> = [
        "cmd-tab", "shift-cmd-tab", "cmd-backtick", "cmd-space", "alt-cmd-space", "ctrl-space", "ctrl-cmd-space",
        "alt-cmd-esc", "ctrl-cmd-q", "shift-cmd-q", "ctrl-cmd-f", "alt-cmd-d",
        "shift-cmd-3", "shift-cmd-4", "shift-cmd-5", "ctrl-shift-cmd-3", "ctrl-shift-cmd-4",
        "cmd-a", "cmd-c", "cmd-h", "alt-cmd-h", "cmd-m", "cmd-n", "cmd-o", "cmd-p", "cmd-s", "cmd-v",
        "cmd-w", "cmd-x", "cmd-z", "shift-cmd-z",
        "ctrl-left", "ctrl-right", "ctrl-up", "ctrl-down",
    ]

    /// The hotkey for a recorded key press, or why it is refused. `modes` are the loaded AeroSpace bindings:
    /// a combination they use would fight with AeroSpace for the key.
    public static func validate(keyCode: UInt32, modifiers: Set<Modifier>, modes: [BindingMode] = []) -> Result<Hotkey, HotkeyProblem> {
        guard let hotkey = Hotkey(keyCode: keyCode, modifiers: modifiers) else { return .failure(.unsupportedKey) }
        guard !modifiers.isDisjoint(with: [.ctrl, .alt, .cmd]) else { return .failure(.needsModifier) }
        if menuCombos.contains(hotkey.raw) { return .failure(.usedByMenu) }
        if reservedCombos.contains(hotkey.raw) { return .failure(.reserved) }
        for mode in modes {
            if let binding = mode.bindings.first(where: { $0.combo.canonical == hotkey.raw }) {
                return .failure(.boundInAeroSpace(command: binding.command))
            }
        }
        return .success(hotkey)
    }
}

/// Reads and writes the hotkey as one `UserDefaults` string. Nothing stored, or something unreadable, is the
/// default hotkey.
public struct HotkeyStorage {
    static let key = "hotkey"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> Hotkey {
        (defaults.string(forKey: Self.key)).flatMap(Hotkey.init(raw:)) ?? .default
    }

    public func save(_ hotkey: Hotkey) {
        if hotkey == .default { defaults.removeObject(forKey: Self.key) } else { defaults.set(hotkey.raw, forKey: Self.key) }
    }
}
