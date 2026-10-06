import AppKit
import SwiftUI

/// Where the suggestion bubble sits and how it looks, in one value. The bubble reads nothing else, so a
/// later settings feature only has to build one of these. The defaults are the shipped look.
public struct BubbleStyle {
    public enum Corner: Equatable { case topLeft, topRight }

    /// Which corner of the screen's visible frame the bubble hugs. Top right by default: the top left would
    /// cover the close and minimise buttons of windows.
    public var corner: Corner = .topRight
    /// Inset from the visible frame. The top inset clears SketchyBar (about 74 pt from the screen top).
    public var margins = CGSize(width: 16, height: 80)
    /// How long the bubble stays up; the controller's self-feedback guard only has to stay well below it.
    public var duration: TimeInterval = 4
    public var fadeOutDuration: TimeInterval = 0.25

    public var cornerRadius: CGFloat = 14
    public var padding = CGSize(width: 16, height: 10)
    /// Space between the keycap group and the text column.
    public var contentSpacing: CGFloat = 12
    public var keycapSpacing: CGFloat = 4
    public var keycapCornerRadius: CGFloat = 7
    public var keycapPadding = CGSize(width: 10, height: 4)

    public var background = AnyShapeStyle(Material.regularMaterial)
    public var keycapFill = AnyShapeStyle(HierarchicalShapeStyle.quaternary)
    public var hintStyle = AnyShapeStyle(HierarchicalShapeStyle.secondary)

    public init() {}

    /// Bottom-left origin (AppKit coordinates) of a bubble of `size` inside `visibleFrame`.
    public func origin(for size: CGSize, in visibleFrame: CGRect) -> CGPoint {
        let x = corner == .topRight
            ? visibleFrame.maxX - size.width - margins.width
            : visibleFrame.minX + margins.width
        return CGPoint(x: x, y: visibleFrame.maxY - size.height - margins.height)
    }
}
