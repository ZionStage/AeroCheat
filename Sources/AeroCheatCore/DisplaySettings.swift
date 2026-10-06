import Foundation

/// Where the bubble sits on the screen: a 3x3 grid of anchors.
public enum BubbleAnchor: String, CaseIterable, Equatable {
    case topLeft, topCenter, topRight
    case middleLeft, center, middleRight
    case bottomLeft, bottomCenter, bottomRight

    public enum Alignment: Equatable { case start, middle, end }

    /// Left, centre or right column.
    public var horizontal: Alignment {
        switch self {
        case .topLeft, .middleLeft, .bottomLeft: return .start
        case .topCenter, .center, .bottomCenter: return .middle
        case .topRight, .middleRight, .bottomRight: return .end
        }
    }

    /// Top, middle or bottom row.
    public var vertical: Alignment {
        switch self {
        case .topLeft, .topCenter, .topRight: return .start
        case .middleLeft, .center, .middleRight: return .middle
        case .bottomLeft, .bottomCenter, .bottomRight: return .end
        }
    }

    /// Rows of the picker, top to bottom.
    public static let grid: [[BubbleAnchor]] = [
        [.topLeft, .topCenter, .topRight],
        [.middleLeft, .center, .middleRight],
        [.bottomLeft, .bottomCenter, .bottomRight],
    ]

    public var title: String {
        switch self {
        case .topLeft: return "Top left"
        case .topCenter: return "Top centre"
        case .topRight: return "Top right"
        case .middleLeft: return "Middle left"
        case .center: return "Centre"
        case .middleRight: return "Middle right"
        case .bottomLeft: return "Bottom left"
        case .bottomCenter: return "Bottom centre"
        case .bottomRight: return "Bottom right"
        }
    }
}

/// A colour picked in the settings, as sRGB components in 0...1. Opacity is a separate, overall setting.
public struct SettingsColor: Equatable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Components clamped to 0...1; `nil` if any is not a finite number.
    var normalized: SettingsColor? {
        guard red.isFinite, green.isFinite, blue.isFinite else { return nil }
        return SettingsColor(red: min(max(red, 0), 1), green: min(max(green, 0), 1), blue: min(max(blue, 0), 1))
    }
}

/// A kind of suggestion that can be switched on or off in the settings. A new kind of suggestion adds a case
/// here (and a branch in `Suggestion.kind`); the settings panel lists `allCases`, so it needs no change.
public enum SuggestionKind: String, CaseIterable, Equatable {
    case workspaceSwitch
    case focusChange

    public var title: String {
        switch self {
        case .workspaceSwitch: return "Workspace switches"
        case .focusChange: return "Window focus"
        }
    }

    public var detail: String {
        switch self {
        case .workspaceSwitch: return "After you switch workspace with the mouse"
        case .focusChange: return "After you click another window of the same workspace"
        }
    }
}

/// Everything the user can configure about the suggestion bubble and when it appears. The defaults are the
/// look and the pacing the app shipped with. UI-free: the UI layer maps it to a `BubbleStyle`, the policy
/// limits come from `policyLimits`.
public struct DisplaySettings: Equatable {
    // MARK: Position

    public var anchor: BubbleAnchor = .topRight
    /// Distance from the left or right edge of the visible frame; ignored in the centre column.
    public var horizontalMargin: Double = 16
    /// Distance from the top or bottom edge of the visible frame; ignored in the middle row. The 80 pt top
    /// default clears SketchyBar (about 74 pt from the screen top).
    public var verticalMargin: Double = 80

    // MARK: Look

    /// `nil` keeps the system look: the translucent material, the primary and secondary text colours.
    public var backgroundColor: SettingsColor?
    public var textColor: SettingsColor?
    /// Tints the keycap group: modifier icons and the key.
    public var iconTint: SettingsColor?
    /// Overall opacity of the bubble.
    public var opacity: Double = 1
    /// Seconds the bubble stays up.
    public var duration: Double = 4
    /// Multiplies the fonts, icons and paddings of the bubble.
    public var scale: Double = 1
    /// Modifier keys as SF Symbol icons (`true`) or as text glyphs (`false`).
    public var iconsForModifiers = true

    // MARK: Behaviour

    /// Kinds switched off. Stored this way round so a kind added later is on for everyone by default.
    public var disabledKinds: Set<SuggestionKind> = []
    /// Minimum seconds between any two bubbles.
    public var tipInterval: Double = 5
    /// Minimum seconds between two bubbles for the same shortcut.
    public var identicalTipInterval: Double = 30

    public init() {}

    public func isEnabled(_ kind: SuggestionKind) -> Bool { !disabledKinds.contains(kind) }

    public mutating func setEnabled(_ kind: SuggestionKind, _ enabled: Bool) {
        if enabled { disabledKinds.remove(kind) } else { disabledKinds.insert(kind) }
    }

    // MARK: Ranges

    public static let marginRange: ClosedRange<Double> = 0...400
    public static let opacityRange: ClosedRange<Double> = 0.3...1
    public static let durationRange: ClosedRange<Double> = 1...30
    public static let scaleRange: ClosedRange<Double> = 0.75...1.75
    public static let tipIntervalRange: ClosedRange<Double> = 0...600
    public static let identicalTipIntervalRange: ClosedRange<Double> = 0...3600

    /// Every value brought into its range; one that is not a finite number goes back to its default.
    public func normalized() -> DisplaySettings {
        let defaults = DisplaySettings()
        func clamp(_ value: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
            value.isFinite ? min(max(value, range.lowerBound), range.upperBound) : fallback
        }
        var result = self
        result.horizontalMargin = clamp(horizontalMargin, Self.marginRange, defaults.horizontalMargin)
        result.verticalMargin = clamp(verticalMargin, Self.marginRange, defaults.verticalMargin)
        result.opacity = clamp(opacity, Self.opacityRange, defaults.opacity)
        result.duration = clamp(duration, Self.durationRange, defaults.duration)
        result.scale = clamp(scale, Self.scaleRange, defaults.scale)
        result.tipInterval = clamp(tipInterval, Self.tipIntervalRange, defaults.tipInterval)
        result.identicalTipInterval = clamp(identicalTipInterval, Self.identicalTipIntervalRange, defaults.identicalTipInterval)
        result.backgroundColor = backgroundColor?.normalized
        result.textColor = textColor?.normalized
        result.iconTint = iconTint?.normalized
        return result
    }

    /// The delays the suggestion policy applies.
    public var policyLimits: SuggestionPolicy.Limits { SuggestionPolicy.Limits(settings: self) }
}

extension SuggestionPolicy.Limits {
    public init(settings: DisplaySettings) {
        self.init()
        minimumToastInterval = settings.tipInterval
        perSuggestionCooldown = settings.identicalTipInterval
    }
}

extension Suggestion {
    /// The kind of suggestion, from what triggered it. A new kind adds a case to `SuggestionKind` and a branch here.
    public var kind: SuggestionKind {
        switch trigger {
        case .workspaceSwitch: return .workspaceSwitch
        case .focusChange: return .focusChange
        }
    }
}

/// Reads and writes `DisplaySettings` as one `UserDefaults` entry per field. A value of the wrong type or
/// not a finite number falls back to the field's default, an out-of-range one is clamped, so a damaged
/// store never breaks the app or the other fields. The defaults object is injected: tests use a throwaway suite.
public struct DisplaySettingsStorage {
    static let prefix = "display."

    enum Key: String, CaseIterable {
        case anchor, horizontalMargin, verticalMargin, backgroundColor, textColor, iconTint
        case opacity, duration, scale, iconsForModifiers, disabledKinds, tipInterval, identicalTipInterval

        var name: String { DisplaySettingsStorage.prefix + rawValue }
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> DisplaySettings {
        var s = DisplaySettings()
        if let raw = defaults.object(forKey: Key.anchor.name) as? String, let anchor = BubbleAnchor(rawValue: raw) { s.anchor = anchor }
        s.horizontalMargin = number(.horizontalMargin) ?? s.horizontalMargin
        s.verticalMargin = number(.verticalMargin) ?? s.verticalMargin
        s.backgroundColor = color(.backgroundColor)
        s.textColor = color(.textColor)
        s.iconTint = color(.iconTint)
        s.opacity = number(.opacity) ?? s.opacity
        s.duration = number(.duration) ?? s.duration
        s.scale = number(.scale) ?? s.scale
        if let flag = defaults.object(forKey: Key.iconsForModifiers.name) as? Bool { s.iconsForModifiers = flag }
        if let names = defaults.object(forKey: Key.disabledKinds.name) as? [String] {
            s.disabledKinds = Set(names.compactMap(SuggestionKind.init(rawValue:)))
        }
        s.tipInterval = number(.tipInterval) ?? s.tipInterval
        s.identicalTipInterval = number(.identicalTipInterval) ?? s.identicalTipInterval
        return s.normalized()
    }

    public func save(_ settings: DisplaySettings) {
        let s = settings.normalized()
        defaults.set(s.anchor.rawValue, forKey: Key.anchor.name)
        defaults.set(s.horizontalMargin, forKey: Key.horizontalMargin.name)
        defaults.set(s.verticalMargin, forKey: Key.verticalMargin.name)
        store(s.backgroundColor, .backgroundColor)
        store(s.textColor, .textColor)
        store(s.iconTint, .iconTint)
        defaults.set(s.opacity, forKey: Key.opacity.name)
        defaults.set(s.duration, forKey: Key.duration.name)
        defaults.set(s.scale, forKey: Key.scale.name)
        defaults.set(s.iconsForModifiers, forKey: Key.iconsForModifiers.name)
        defaults.set(s.disabledKinds.map(\.rawValue).sorted(), forKey: Key.disabledKinds.name)
        defaults.set(s.tipInterval, forKey: Key.tipInterval.name)
        defaults.set(s.identicalTipInterval, forKey: Key.identicalTipInterval.name)
    }

    /// Forgets every stored value: the next `load()` returns the defaults.
    public func clear() {
        Key.allCases.forEach { defaults.removeObject(forKey: $0.name) }
    }

    private func number(_ key: Key) -> Double? {
        guard let value = defaults.object(forKey: key.name) as? Double, value.isFinite else { return nil }
        return value
    }

    private func color(_ key: Key) -> SettingsColor? {
        guard let parts = defaults.object(forKey: key.name) as? [Double], parts.count == 3 else { return nil }
        return SettingsColor(red: parts[0], green: parts[1], blue: parts[2]).normalized
    }

    private func store(_ color: SettingsColor?, _ key: Key) {
        if let color {
            defaults.set([color.red, color.green, color.blue], forKey: key.name)
        } else {
            defaults.removeObject(forKey: key.name)
        }
    }
}
