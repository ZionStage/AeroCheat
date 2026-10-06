import AeroCheatCore
import SwiftUI

/// The suggestion bubble: the shortcut as keycaps, then the title and the optional hint.
public struct BubbleView: View {
    let content: BubbleContent
    let style: BubbleStyle

    public init(content: BubbleContent, style: BubbleStyle = BubbleStyle()) {
        self.content = content
        self.style = style
    }

    public var body: some View {
        HStack(spacing: style.contentSpacing) {
            HStack(spacing: style.keycapSpacing) {
                ForEach(Array(content.caps.enumerated()), id: \.offset) { _, cap in
                    switch cap {
                    case .icon(let name): Image(systemName: name)
                    case .text(let string): Text(string)
                    }
                }
            }
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .padding(.horizontal, style.keycapPadding.width)
                .padding(.vertical, style.keycapPadding.height)
                .background(RoundedRectangle(cornerRadius: style.keycapCornerRadius).fill(style.keycapFill))
            VStack(alignment: .leading, spacing: 1) {
                Text(content.title).font(.callout)
                if let hint = content.hint {
                    Text(hint).font(.caption).foregroundStyle(style.hintStyle)
                }
            }
        }
        .padding(.horizontal, style.padding.width)
        .padding(.vertical, style.padding.height)
        .background(style.background, in: RoundedRectangle(cornerRadius: style.cornerRadius))
        .fixedSize()
    }
}
