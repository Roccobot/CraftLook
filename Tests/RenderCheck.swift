import Foundation
import CoreGraphics

@main struct RenderCheck {
    static func main() throws {
        do {
            let image = try DocumentImage.load(URL(fileURLWithPath: CommandLine.arguments[1]))
            let context = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8,
                bytesPerRow: 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            let bytes = context.data!.assumingMemoryBound(to: UInt8.self)
            print("\(image.width)x\(image.height) \(String(format: "%02x%02x%02x", bytes[0], bytes[1], bytes[2]))")
        } catch {
            FileHandle.standardError.write(Data(error.localizedDescription.utf8))
            exit(1)
        }
    }
}
