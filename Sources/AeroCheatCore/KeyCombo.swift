import Foundation

/// A modifier key in an AeroSpace binding. Declaration order is the macOS display order (⌃⌥⇧⌘).
public enum Modifier: String, CaseIterable, Comparable {
    case ctrl, alt, shift, cmd

    public var symbol: String {
        switch self {
        case .ctrl: return "⌃"
        case .alt: return "⌥"
        case .shift: return "⇧"
        case .cmd: return "⌘"
        }
    }

    public static func < (lhs: Modifier, rhs: Modifier) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }
}

/// A key combination such as `ctrl-alt-shift-h`.
public struct KeyCombo: Equatable {
    /// The combo exactly as written in the config.
    public let raw: String
    public let modifiers: [Modifier]
    /// The AeroSpace key name (`h`, `slash`, `tab`, `1`...).
    public let key: String

    public init(raw: String) {
        self.raw = raw
        let parts = raw.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        var mods: Set<Modifier> = []
        var keyParts = parts[...]
        while keyParts.count > 1, let m = Modifier(rawValue: keyParts.first!.lowercased()) {
            mods.insert(m)
            keyParts = keyParts.dropFirst()
        }
        self.modifiers = mods.sorted()
        self.key = keyParts.joined(separator: "-")
    }

    /// Modifier symbols, e.g. `⌃⌥⇧`.
    public var modifierSymbols: String { modifiers.map(\.symbol).joined() }

    /// The key as printed on a keycap, e.g. `H`, `/`, `⇥`.
    public var keyDisplay: String { KeyCombo.keyGlyphs[key.lowercased()] ?? key.uppercased() }

    /// Full display string, e.g. `⌃⌥⇧ H`.
    public var display: String {
        modifiers.isEmpty ? keyDisplay : "\(modifierSymbols) \(keyDisplay)"
    }

    /// Spelled-out modifiers for search, e.g. `ctrl alt shift`.
    public var modifierWords: String { modifiers.map(\.rawValue).joined(separator: " ") }

    private static let keyGlyphs: [String: String] = [
        "slash": "/", "comma": ",", "period": ".", "semicolon": ";", "quote": "'",
        "minus": "-", "equal": "=", "backtick": "`", "backslash": "\\",
        "leftsquarebracket": "[", "rightsquarebracket": "]",
        "space": "␣", "tab": "⇥", "enter": "↩", "esc": "⎋", "backspace": "⌫", "delete": "⌦",
        "left": "←", "right": "→", "up": "↑", "down": "↓",
        "keypadclear": "⌧", "keypadplus": "Num +", "keypadminus": "Num -",
        "keypadmultiply": "Num *", "keypaddivide": "Num /", "keypaddecimal": "Num .",
        "keypadequals": "Num =", "keypadenter": "Num ↩",
    ]
}
