import Foundation
import CoreGraphics

@main struct RenderCheck {
    static func context(_ width: Int, _ height: Int) -> CGContext {
        CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    }

    static func hex(_ context: CGContext, _ x: Int, _ y: Int) -> String {
        let bytes = context.data!.assumingMemoryBound(to: UInt8.self)
        let p = y * context.bytesPerRow + x * 4
        return String(format: "%02x%02x%02x", bytes[p], bytes[p + 1], bytes[p + 2])
    }

    static func main() throws {
        let arguments = CommandLine.arguments
        if arguments[1] == "--fill" {
            // A thumbnail context as Quick Look hands it over: pixels, without a scale transform.
            let red = context(2, 1)
            red.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
            red.fill(CGRect(x: 0, y: 0, width: 2, height: 1))
            let target = context(Int(arguments[2])!, Int(arguments[3])!)
            DocumentImage.fill(target, with: red.makeImage()!)
            let (w, h) = (target.width - 1, target.height - 1)
            print([(0, 0), (w, 0), (0, h), (w, h)].map { hex(target, $0.0, $0.1) }.joined(separator: " "))
            return
        }
        if arguments[1] == "--svg-resources" {
            // The same-folder files an SVG would hand to the renderer, as the extension collects them.
            let file = URL(fileURLWithPath: arguments[2])
            let found = SVGResource.contents(in: try Data(contentsOf: file), nextTo: file, limit: 32 << 20)
            print(found.keys.sorted().joined(separator: " "))
            return
        }
        do {
            let image = try DocumentImage.load(URL(fileURLWithPath: arguments[1]))
            let pixel = context(1, 1)
            pixel.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            print("\(image.width)x\(image.height) \(hex(pixel, 0, 0))")
        } catch {
            FileHandle.standardError.write(Data(error.localizedDescription.utf8))
            exit(1)
        }
    }
}
