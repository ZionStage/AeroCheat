import Foundation

/// One element of a shortcut as the suggestion bubble draws it.
public enum KeyCap: Equatable {
    /// A modifier shown as an SF Symbol; `glyph` is the text to use when the symbol is unavailable.
    case symbol(name: String, glyph: String)
    /// Any other key, drawn as keycap-style text.
    case text(String)
}

extension Modifier {
    /// SF Symbol name of the modifier (macOS 13+).
    public var symbolName: String {
        switch self {
        case .ctrl: return "control"
        case .alt: return "option"
        case .shift: return "shift"
        case .cmd: return "command"
        }
    }
}

extension KeyCombo {
    /// Modifiers as icons followed by the key as text, e.g. `ctrl-alt-3` gives control, option, `3`.
    public var keyCaps: [KeyCap] {
        modifiers.map { KeyCap.symbol(name: $0.symbolName, glyph: $0.symbol) } + [.text(keyDisplay)]
    }
}

extension KeyCap {
    /// What to draw: an icon when `symbolAvailable` knows the symbol, otherwise the text glyph.
    public enum Rendering: Equatable {
        case icon(String)
        case text(String)
    }

    public func rendering(symbolAvailable: (String) -> Bool) -> Rendering {
        switch self {
        case .symbol(let name, let glyph):
            return symbolAvailable(name) ? .icon(name) : .text(glyph)
        case .text(let string):
            return .text(string)
        }
    }
}
