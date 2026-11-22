import Foundation
import CoreGraphics
import CoreText

/// Bitmaps drawn by the app itself: the SoundCraft timeline and the FilmCraft placeholders.
enum Drawing {
    /// The colour of a placeholder and of the timeline's playhead.
    static let green = color(0x43, 0xB5, 0x9E)

    static func color(_ r: Int, _ g: Int, _ b: Int, _ alpha: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: alpha)
    }

    /// A transparent sRGB bitmap whose coordinates run from the top left, in points of `scale` pixels.
    static func canvas(width: Int, height: Int, scale: CGFloat = 1) throws -> CGContext {
        guard width > 0, height > 0, height <= 100_000_000 / width,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw ReadError.limit }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: scale, y: -scale)
        return context
    }

    static func roundedRect(_ context: CGContext, _ rect: CGRect, radius: CGFloat, fill: CGColor) {
        let r = max(0, min(radius, rect.width / 2, rect.height / 2))
        context.addPath(CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil))
        context.setFillColor(fill)
        context.fillPath()
    }

    /// One line of text whose top left is at `point`, cut with an ellipsis at `width`.
    static func text(_ context: CGContext, _ string: String, at point: CGPoint, size: CGFloat,
                     bold: Bool = false, color: CGColor, width: CGFloat = .greatestFiniteMagnitude) {
        guard !string.isEmpty, width > size else { return }
        let font = CTFontCreateUIFontForLanguage(bold ? .emphasizedSystem : .system, size, nil)
            ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
        let attributes = [kCTFontAttributeName: font, kCTForegroundColorAttributeName: color] as CFDictionary
        func line(_ s: String) -> CTLine { CTLineCreateWithAttributedString(CFAttributedStringCreate(nil, s as CFString, attributes)) }
        guard let fitted = CTLineCreateTruncatedLine(line(string), Double(width), .end, line("\u{2026}")) else { return }
        context.saveGState()
        context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        context.textPosition = CGPoint(x: point.x, y: point.y + CTFontGetAscent(font))
        CTLineDraw(fitted, context)
        context.restoreGState()
    }

    /// What FilmCraft shows in place of a missing picture: a rounded rectangle in the placeholder green,
    /// with a play sign for a movie and a landscape for a still.
    static func placeholder(width: Int, height: Int, movie: Bool) throws -> CGImage {
        let context = try canvas(width: width, height: height)
        let (w, h) = (CGFloat(width), CGFloat(height))
        let short = min(w, h)
        roundedRect(context, CGRect(x: 0, y: 0, width: w, height: h), radius: short * 0.06, fill: green)
        let mark = color(255, 255, 255, 0.85)
        let side = short * 0.28
        let box = CGRect(x: (w - side) / 2, y: (h - side) / 2, width: side, height: side)
        context.setFillColor(mark)
        if movie {
            context.move(to: CGPoint(x: box.minX + side * 0.2, y: box.minY + side * 0.1))
            context.addLine(to: CGPoint(x: box.maxX - side * 0.05, y: box.midY))
            context.addLine(to: CGPoint(x: box.minX + side * 0.2, y: box.maxY - side * 0.1))
            context.closePath()
            context.fillPath()
        } else {
            context.fillEllipse(in: CGRect(x: box.maxX - side * 0.32, y: box.minY + side * 0.08,
                                           width: side * 0.24, height: side * 0.24))
            context.move(to: CGPoint(x: box.minX, y: box.maxY - side * 0.08))
            context.addLine(to: CGPoint(x: box.minX + side * 0.38, y: box.minY + side * 0.38))
            context.addLine(to: CGPoint(x: box.minX + side * 0.62, y: box.minY + side * 0.62))
            context.addLine(to: CGPoint(x: box.minX + side * 0.74, y: box.minY + side * 0.5))
            context.addLine(to: CGPoint(x: box.maxX, y: box.maxY - side * 0.08))
            context.closePath()
            context.fillPath()
        }
        guard let image = context.makeImage() else { throw ReadError.invalid }
        return image
    }
}
