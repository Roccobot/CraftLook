import AppKit
#if canImport(Sparkle)
import Sparkle
#endif

/// Draws the app window (Sources/Intro.swift) offscreen, in the light and the dark theme, without
/// showing it or bringing anything to the front: WindowSnapshot <Resources folder> <output folder>.
@main
enum WindowSnapshot {
    static func main() throws {
        let arguments = CommandLine.arguments
        guard arguments.count == 3 else {
            FileHandle.standardError.write(Data("usage: WindowSnapshot <Resources folder> <output folder>\n".utf8))
            exit(2)
        }
        let resources = URL(fileURLWithPath: arguments[1])
        let output = URL(fileURLWithPath: arguments[2])
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        _ = NSApplication.shared
        let icon = NSImage(contentsOf: resources.appendingPathComponent("CraftLook.icns")) ?? NSImage()
        #if canImport(Sparkle)
        // Not started: the snapshot never checks for updates.
        let updates = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
        let intro = Intro(resources: resources, icon: icon, updates: updates)
        #else
        let intro = Intro(resources: resources, icon: icon)
        #endif
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: Intro.column + 2 * Intro.margin, height: 10),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: appearance)
            window.title = "CraftLook"
            Intro.style(window)
            window.contentView = intro.view()
            window.setContentSize(window.contentView!.fittingSize)
            let view = window.contentView!
            view.layoutSubtreeIfNeeded()
            // The window background, then the view, at 2x.
            let scale: CGFloat = 2
            let size = view.bounds.size
            guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                                                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { exit(1) }
            bitmap.size = size
            NSAppearance(named: appearance)!.performAsCurrentDrawingAppearance {
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
                NSColor.windowBackgroundColor.setFill()
                NSRect(origin: .zero, size: size).fill()
                NSGraphicsContext.restoreGraphicsState()
                view.cacheDisplay(in: view.bounds, to: bitmap)
            }
            let file = output.appendingPathComponent("window-\(name).png")
            try bitmap.representation(using: .png, properties: [:])!.write(to: file)
            print(file.path, Int(size.width), "x", Int(size.height))
            // Every row must keep the margins, measured on its alignment rectangle, the one Auto Layout
            // places: a text field's frame is wider than its text by a small inset on each side.
            // Containers (the glass panels) may come closer to the edges; texts, buttons and images may not.
            var leaves = 0
            func check(_ sub: NSView) {
                if sub is NSControl || sub is NSImageView {
                    leaves += 1
                    let rect = view.convert(sub.alignmentRect(forFrame: sub.frame), from: sub.superview)
                    if rect.minX < Intro.margin - 0.5 || rect.maxX > size.width - Intro.margin + 0.5 {
                        print("FAIL: \(type(of: sub)) \((sub as? NSTextField)?.stringValue ?? (sub as? NSButton)?.title ?? "") at \(rect) crosses the margins")
                        exit(1)
                    }
                    return
                }
                sub.subviews.forEach(check)
            }
            view.subviews.forEach(check)
            print("margins: \(leaves) texts, buttons and images inside \(Intro.margin) points")
        }
    }
}
