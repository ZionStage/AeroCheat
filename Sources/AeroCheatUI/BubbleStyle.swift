import AeroCheatCore
import AppKit
import SwiftUI

/// Where the suggestion bubble sits and how it looks, in one value. The bubble reads nothing else, so the
/// settings only have to build one of these (`init(settings:)`). The defaults are the shipped look.
public struct BubbleStyle {
    /// Which point of the screen's visible frame the bubble hugs. Top right by default: the top left would
    /// cover the close and minimise buttons of windows.
    public var anchor: BubbleAnchor = .topRight
    /// Inset from the visible frame: `width` from the left or right edge, `height` from the top or bottom
    /// edge. Not applied along an axis the anchor centres. The top inset clears SketchyBar (about 74 pt from
    /// the screen top).
    public var margins = CGSize(width: 16, height: 80)
    /// How long the bubble stays up; the controller's self-feedback guard only has to stay well below it.
    public var duration: TimeInterval = 4
    public var fadeOutDuration: TimeInterval = 0.25
    /// Opacity of the whole bubble.
    public var opacity: Double = 1

    public var cornerRadius: CGFloat = 14
    public var padding = CGSize(width: 16, height: 10)
    /// Space between the keycap group and the text column.
    public var contentSpacing: CGFloat = 12
    public var keycapSpacing: CGFloat = 4
    public var keycapCornerRadius: CGFloat = 7
    public var keycapPadding = CGSize(width: 10, height: 4)

    /// Point sizes of the keys and modifier icons, of the title line and of the hint line.
    public var keyFontSize: CGFloat = 15
    public var titleFontSize: CGFloat = 12
    public var hintFontSize: CGFloat = 10

    public var background = AnyShapeStyle(Material.regularMaterial)
    public var keycapFill = AnyShapeStyle(HierarchicalShapeStyle.quaternary)
    /// Colour of the keycap group: modifier icons and the key.
    public var keycapStyle = AnyShapeStyle(HierarchicalShapeStyle.primary)
    public var titleStyle = AnyShapeStyle(HierarchicalShapeStyle.primary)
    public var hintStyle = AnyShapeStyle(HierarchicalShapeStyle.secondary)

    public init() {}

    /// The style the settings describe. `DisplaySettings()` gives `BubbleStyle()` exactly.
    public init(settings: DisplaySettings) {
        self.init()
        let settings = settings.normalized()
        let scale = CGFloat(settings.scale)
        anchor = settings.anchor
        margins = CGSize(width: settings.horizontalMargin, height: settings.verticalMargin)
        duration = settings.duration
        opacity = settings.opacity

        cornerRadius *= scale
        padding = CGSize(width: padding.width * scale, height: padding.height * scale)
        contentSpacing *= scale
        keycapSpacing *= scale
        keycapCornerRadius *= scale
        keycapPadding = CGSize(width: keycapPadding.width * scale, height: keycapPadding.height * scale)
        keyFontSize *= scale
        titleFontSize *= scale
        hintFontSize *= scale

        if let color = settings.backgroundColor { background = AnyShapeStyle(color.color) }
        if let color = settings.textColor {
            titleStyle = AnyShapeStyle(color.color)
            hintStyle = AnyShapeStyle(color.color.opacity(0.7))
            keycapStyle = AnyShapeStyle(color.color)
        }
        // The tint wins over the text colour for the keycap group.
        if let color = settings.iconTint { keycapStyle = AnyShapeStyle(color.color) }
    }

    /// Bottom-left origin (AppKit coordinates) of a bubble of `size` inside `visibleFrame`. Always inside the
    /// frame when the bubble fits in it, however large the margins.
    public func origin(for size: CGSize, in visibleFrame: CGRect) -> CGPoint {
        let x: CGFloat
        switch anchor.horizontal {
        case .start: x = visibleFrame.minX + margins.width
        case .middle: x = visibleFrame.midX - size.width / 2
        case .end: x = visibleFrame.maxX - size.width - margins.width
        }
        let y: CGFloat
        switch anchor.vertical {
        case .start: y = visibleFrame.maxY - size.height - margins.height
        case .middle: y = visibleFrame.midY - size.height / 2
        case .end: y = visibleFrame.minY + margins.height
        }
        return CGPoint(
            x: min(max(x, visibleFrame.minX), max(visibleFrame.minX, visibleFrame.maxX - size.width)),
            y: min(max(y, visibleFrame.minY), max(visibleFrame.minY, visibleFrame.maxY - size.height))
        )
    }
}

extension SettingsColor {
    public var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: 1) }

    /// `nil` if the colour has no sRGB representation.
    public init?(_ color: Color) {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return nil }
        self.init(red: Double(rgb.redComponent), green: Double(rgb.greenComponent), blue: Double(rgb.blueComponent))
    }
}
