import AeroCheatCore
import AeroCheatUI
import AppKit
import SwiftUI
import XCTest

/// Renders the bubble into a bitmap with no screen, window or app session: an `NSHostingView` that never
/// joins a window, drawn with `cacheDisplay`.
@MainActor
enum BubbleRender {
    struct Result {
        let size: CGSize
        let bitmap: NSBitmapImageRep

        /// Pixels that are not fully transparent.
        var paintedPixelCount: Int {
            var count = 0
            for y in 0..<bitmap.pixelsHigh {
                for x in 0..<bitmap.pixelsWide where (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.01 { count += 1 }
            }
            return count
        }

        /// Pixels that are clearly dark: the text and the icons of the aqua appearance.
        var inkPixelCount: Int {
            var count = 0
            for y in 0..<bitmap.pixelsHigh {
                for x in 0..<bitmap.pixelsWide {
                    guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB), color.alphaComponent > 0.5 else { continue }
                    if color.redComponent < 0.35, color.greenComponent < 0.35, color.blueComponent < 0.35 { count += 1 }
                }
            }
            return count
        }
    }

    static func suggestion(_ binding: String, workspace: String = "3", backAndForth: String? = nil) throws -> Suggestion {
        var config = "[mode.main.binding]\n\(binding) = 'workspace \(workspace)'\n"
        if let backAndForth { config += "\(backAndForth) = 'workspace-back-and-forth'\n" }
        let resolver = ActionResolver(modes: try AeroSpaceConfig.parse(config))
        let mouseSwitch = MouseSwitch(from: "9", to: workspace, returnsToPrevious: backAndForth != nil)
        return try XCTUnwrap(resolver.suggestion(for: mouseSwitch))
    }

    static func render(_ content: BubbleContent, style: BubbleStyle = BubbleStyle()) throws -> Result {
        let hosting = NSHostingView(rootView: BubbleView(content: content, style: style))
        hosting.appearance = NSAppearance(named: .aqua)
        let size = hosting.fittingSize
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        try save(bitmap, named: content.title)
        return Result(size: size, bitmap: bitmap)
    }

    /// Set `AEROCHEAT_SNAPSHOT_DIR` to also get each rendering as a PNG to look at; nothing is written otherwise.
    private static func save(_ bitmap: NSBitmapImageRep, named name: String) throws {
        guard let directory = ProcessInfo.processInfo.environment["AEROCHEAT_SNAPSHOT_DIR"] else { return }
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let file = name.replacingOccurrences(of: " ", with: "-") + "-\(bitmap.pixelsWide)x\(bitmap.pixelsHigh).png"
        try png.write(to: URL(fileURLWithPath: directory).appendingPathComponent(file))
    }
}
