import AeroCheatCore
import AppKit

/// What the bubble says, with every key already resolved to an icon or a text fallback.
public struct BubbleContent: Equatable {
    public let caps: [KeyCap.Rendering]
    public let title: String
    public let hint: String?

    /// `symbolAvailable` decides, per SF Symbol name, between the icon and the glyph text.
    public init(suggestion: Suggestion, symbolAvailable: (String) -> Bool = BubbleContent.systemSymbolAvailable) {
        caps = suggestion.binding.combo.keyCaps.map { $0.rendering(symbolAvailable: symbolAvailable) }
        title = suggestion.title
        hint = suggestion.hint
    }

    public static func systemSymbolAvailable(_ name: String) -> Bool {
        NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
    }
}
