import AppKit

/// The menu bar logo, decoded from PNG data compiled into the executable (see `MenuBarGlyphData`), so it needs
/// no resource bundle: `Bundle.module` would crash if the executable were copied without it.
public enum MenuBarLogo {
    /// The size the glyph is drawn at, in points.
    public static let size = NSSize(width: 18, height: 18)

    /// An 18 pt template image with 1x and 2x representations, or nil if the embedded data cannot be decoded.
    /// As a template image it is black with alpha and macOS tints it for light, dark and highlighted menu bars.
    public static func makeImage() -> NSImage? {
        let image = NSImage(size: size)
        for encoded in [MenuBarGlyphData.png1x, MenuBarGlyphData.png2x] {
            guard let data = Data(base64Encoded: encoded, options: .ignoreUnknownCharacters),
                  let representation = NSBitmapImageRep(data: data) else { return nil }
            representation.size = size
            image.addRepresentation(representation)
        }
        image.isTemplate = true
        return image
    }
}
