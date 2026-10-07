#!/usr/bin/env swift
// Draws the AeroCheat logo and regenerates every derived file, deterministically (CoreGraphics + AppKit only):
//
//   Assets/AppIcon.png                          1024x1024 colour app icon
//   Assets/AppIcon.icns                         built from the PNG with the system `iconutil`
//   Assets/MenuBarIcon.png, MenuBarIcon@2x.png  18x18 and 36x36 black-with-alpha glyph (template image)
//   Sources/AeroCheatUI/MenuBarGlyphData.swift  the two glyph PNGs as base64, embedded in the binary
//
// Run from the repository root:  swift scripts/render-logo.swift
//
// The logo is a crib note, the folded scrap of paper a cheater hides in a sleeve: a slightly tilted note with a
// dog-eared corner, the Command symbol on top and two lines of "notes" below. It reads as a cheat sheet of
// keyboard shortcuts.
import AppKit

// MARK: - Drawing helpers

func bitmap(_ width: Int, _ height: Int) -> CGContext {
    CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
              space: CGColorSpace(name: CGColorSpace.sRGB)!,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: alpha)
}

func radians(_ degrees: CGFloat) -> CGFloat { degrees * .pi / 180 }

func roundedRect(_ width: CGFloat, _ height: CGFloat, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: CGRect(x: -width / 2, y: -height / 2, width: width, height: height),
           cornerWidth: radius, cornerHeight: radius, transform: nil)
}

/// The Command symbol as a centre line, centred on the origin: a square of half-side `a` whose four corners
/// each extend into a loop of radius `r`. Stroke it with round caps and joins.
func commandPath(a: CGFloat, r: CGFloat) -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: -a, y: -a))
    path.addLine(to: CGPoint(x: -a, y: a))
    path.addLine(to: CGPoint(x: a, y: a))
    path.addLine(to: CGPoint(x: a, y: -a))
    path.closeSubpath()
    for sx in [CGFloat(1), -1] {
        for sy in [CGFloat(1), -1] {
            let loop = CGMutablePath()  // drawn for the top-left corner, then mirrored
            loop.move(to: CGPoint(x: -a, y: a))
            loop.addLine(to: CGPoint(x: -a - r, y: a))
            loop.addArc(center: CGPoint(x: -a - r, y: a + r), radius: r,
                        startAngle: -.pi / 2, endAngle: 0, clockwise: true)
            loop.addLine(to: CGPoint(x: -a, y: a))
            path.addPath(loop, transform: CGAffineTransform(scaleX: sx, y: sy))
        }
    }
    return path
}

func strokeCommand(_ ctx: CGContext, at center: CGPoint = .zero, a: CGFloat, r: CGFloat, width: CGFloat, angle: CGFloat = 0) {
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.rotate(by: angle)
    ctx.setLineWidth(width)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.addPath(commandPath(a: a, r: r))
    ctx.strokePath()
    ctx.restoreGState()
}

func withShadow(_ ctx: CGContext, blur: CGFloat = 22, dy: CGFloat = -10, alpha: CGFloat = 0.35, _ body: () -> Void) {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: dy), blur: blur, color: rgb(0x000000, alpha))
    body()
    ctx.restoreGState()
}

/// A note of the given size, centred on the origin, with its top-right corner folded over.
func notePath(_ width: CGFloat, _ height: CGFloat, fold: CGFloat, radius r: CGFloat) -> CGPath {
    let x0 = -width / 2, x1 = width / 2, y0 = -height / 2, y1 = height / 2
    let path = CGMutablePath()
    path.move(to: CGPoint(x: x0 + r, y: y0))
    path.addLine(to: CGPoint(x: x1 - r, y: y0))
    path.addArc(tangent1End: CGPoint(x: x1, y: y0), tangent2End: CGPoint(x: x1, y: y0 + r), radius: r)
    path.addLine(to: CGPoint(x: x1, y: y1 - fold))
    path.addLine(to: CGPoint(x: x1 - fold, y: y1))
    path.addLine(to: CGPoint(x: x0 + r, y: y1))
    path.addArc(tangent1End: CGPoint(x: x0, y: y1), tangent2End: CGPoint(x: x0, y: y1 - r), radius: r)
    path.addLine(to: CGPoint(x: x0, y: y0 + r))
    path.addArc(tangent1End: CGPoint(x: x0, y: y0), tangent2End: CGPoint(x: x0 + r, y: y0), radius: r)
    path.closeSubpath()
    return path
}

func strokeLine(_ ctx: CGContext, from: CGPoint, to: CGPoint, width: CGFloat) {
    ctx.setLineWidth(width)
    ctx.setLineCap(.round)
    ctx.move(to: from)
    ctx.addLine(to: to)
    ctx.strokePath()
}

// MARK: - Colour app icon (1024 x 1024)

func drawAppIcon(_ ctx: CGContext) {
    // Rounded-square tile, 824 pt inside the 1024 canvas as in Apple's icon grid.
    let tile = CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824),
                      cornerWidth: 185, cornerHeight: 185, transform: nil)
    withShadow(ctx, blur: 28, dy: -14) {
        ctx.addPath(tile); ctx.setFillColor(rgb(0x7A1D0E)); ctx.fillPath()
    }
    ctx.saveGState()
    ctx.addPath(tile); ctx.clip()
    // Hot orange to deep brick red, deliberately far from the generic blue tile.
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [rgb(0xFF8A3D), rgb(0x7A1D0E)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 300, y: 924), end: CGPoint(x: 724, y: 100),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()

    // The crib note, tilted, with its folded corner.
    let paper: UInt32 = 0xFFF6D8, ink: UInt32 = 0x7A1D0E
    let width: CGFloat = 430, height: CGFloat = 580, fold: CGFloat = 120
    ctx.saveGState()
    ctx.translateBy(x: 512, y: 500)
    ctx.rotate(by: radians(-9))
    withShadow(ctx) { ctx.addPath(notePath(width, height, fold: fold, radius: 30)); ctx.setFillColor(rgb(paper)); ctx.fillPath() }
    // The flap: the folded-over corner, a shade darker.
    ctx.setFillColor(rgb(0xE9D18F))
    ctx.move(to: CGPoint(x: width / 2 - fold, y: height / 2))
    ctx.addLine(to: CGPoint(x: width / 2 - fold, y: height / 2 - fold))
    ctx.addLine(to: CGPoint(x: width / 2, y: height / 2 - fold))
    ctx.closePath()
    ctx.fillPath()
    ctx.setStrokeColor(rgb(ink))
    strokeCommand(ctx, at: CGPoint(x: -30, y: 90), a: 34, r: 32, width: 28)
    strokeLine(ctx, from: CGPoint(x: -130, y: -90), to: CGPoint(x: 130, y: -90), width: 26)
    strokeLine(ctx, from: CGPoint(x: -130, y: -160), to: CGPoint(x: 40, y: -160), width: 26)
    ctx.restoreGState()
}

// MARK: - Menu bar glyph (black with alpha, designed on a 100 x 100 grid)

func drawGlyph(_ ctx: CGContext) {
    ctx.saveGState()
    ctx.translateBy(x: 50, y: 50)
    ctx.rotate(by: radians(-9))
    ctx.setFillColor(rgb(0x000000))
    ctx.setStrokeColor(rgb(0x000000))
    ctx.addPath(notePath(68, 90, fold: 24, radius: 9)); ctx.fillPath()
    // Command symbol and two lines are knocked out of the note.
    ctx.setBlendMode(.clear)
    strokeCommand(ctx, at: CGPoint(x: -4, y: 15), a: 8.5, r: 6.5, width: 6.8)
    strokeLine(ctx, from: CGPoint(x: -21, y: -19), to: CGPoint(x: 21, y: -19), width: 7)
    strokeLine(ctx, from: CGPoint(x: -21, y: -34), to: CGPoint(x: 5, y: -34), width: 7)
    ctx.restoreGState()
}

// MARK: - Output

func render(_ pixels: Int, canvas: CGFloat, _ draw: (CGContext) -> Void) -> CGImage {
    let ctx = bitmap(pixels, pixels)
    ctx.interpolationQuality = .high
    ctx.scaleBy(x: CGFloat(pixels) / canvas, y: CGFloat(pixels) / canvas)
    draw(ctx)
    return ctx.makeImage()!
}

func resized(_ image: CGImage, to pixels: Int) -> CGImage {
    let ctx = bitmap(pixels, pixels)
    ctx.interpolationQuality = .high
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    return ctx.makeImage()!
}

func pngData(_ image: CGImage) -> Data {
    NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
}

func write(_ data: Data, _ url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url)
    print("wrote \(url.path)")
}

func base64Block(_ data: Data) -> String {
    let encoded = data.base64EncodedString()
    var lines: [String] = []
    var index = encoded.startIndex
    while index < encoded.endIndex {
        let end = encoded.index(index, offsetBy: 96, limitedBy: encoded.endIndex) ?? encoded.endIndex
        lines.append("        " + encoded[index..<end])
        index = end
    }
    return lines.joined(separator: "\n")
}

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("Assets")

let icon = render(1024, canvas: 1024, drawAppIcon)
try write(pngData(icon), assets.appendingPathComponent("AppIcon.png"))

let glyph1x = pngData(render(18, canvas: 100, drawGlyph))
let glyph2x = pngData(render(36, canvas: 100, drawGlyph))
try write(glyph1x, assets.appendingPathComponent("MenuBarIcon.png"))
try write(glyph2x, assets.appendingPathComponent("MenuBarIcon@2x.png"))

try write(Data("""
// Generated by scripts/render-logo.swift. Do not edit by hand.
// The menu bar glyph as PNG data, so the executable needs no resource bundle to show its icon.
enum MenuBarGlyphData {
    /// 18 x 18 pixels, for a 1x display.
    static let png1x = \"\"\"
\(base64Block(glyph1x))
        \"\"\"

    /// 36 x 36 pixels, for a 2x display.
    static let png2x = \"\"\"
\(base64Block(glyph2x))
        \"\"\"
}

""".utf8), root.appendingPathComponent("Sources/AeroCheatUI/MenuBarGlyphData.swift"))

// The .icns comes from the system `iconutil`; skip it quietly where the tool is missing.
let iconutil = URL(fileURLWithPath: "/usr/bin/iconutil")
if FileManager.default.isExecutableFile(atPath: iconutil.path) {
    let iconset = FileManager.default.temporaryDirectory
        .appendingPathComponent("AeroCheat-\(ProcessInfo.processInfo.processIdentifier).iconset")
    try? FileManager.default.removeItem(at: iconset)
    for size in [16, 32, 128, 256, 512] {
        try write(pngData(resized(icon, to: size)), iconset.appendingPathComponent("icon_\(size)x\(size).png"))
        try write(pngData(resized(icon, to: size * 2)), iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
    }
    let process = Process()
    process.executableURL = iconutil
    process.arguments = ["-c", "icns", iconset.path, "-o", assets.appendingPathComponent("AppIcon.icns").path]
    try process.run()
    process.waitUntilExit()
    try? FileManager.default.removeItem(at: iconset)
    if process.terminationStatus != 0 { print("iconutil failed"); exit(1) }
    print("wrote \(assets.appendingPathComponent("AppIcon.icns").path)")
} else {
    print("iconutil not found: AppIcon.icns not regenerated")
}
