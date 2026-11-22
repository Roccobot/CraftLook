import Foundation
import CoreGraphics

@main struct HeadlessCheck {
    static func main() throws {
        let tools = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        for path in CommandLine.arguments.dropFirst(2) {
            let file = URL(fileURLWithPath: path)
            let start = Date()
            guard let image = HeadlessRenderer.render(file, maxSide: 2048, tools: tools),
                  max(image.width,image.height) >= 600 else {
                throw failure("Il renderer non ha prodotto un'anteprima dettagliata per \(file.lastPathComponent)")
            }
            let seconds = Date().timeIntervalSince(start)
            // The offline sample's only picture is a missing still over the whole frame: the placeholder.
            // FilmCraft converts colours to its working space, so the green may move by a few steps.
            if file.lastPathComponent.hasPrefix("offline."),
               zip(pixel(image, 0.25, 0.5), [0x43, 0xB5, 0x9E]).contains(where: { abs($0 - $1) > 8 }) {
                throw failure("\(file.lastPathComponent) non mostra il segnaposto (\(pixel(image, 0.25, 0.5)))")
            }
            print(String(format: "%@: %d × %d, %.2f s", file.lastPathComponent, image.width, image.height, seconds))
        }
    }

    static func failure(_ message: String) -> Error {
        NSError(domain: "HeadlessCheck", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    /// The colour at a point given as fractions of the width and of the height from the top left.
    static func pixel(_ image: CGImage, _ x: Double, _ y: Double) -> [Int] {
        let context = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let (w, h) = (Double(image.width), Double(image.height))
        context.draw(image, in: CGRect(x: -(x * w).rounded(), y: -((1 - y) * h).rounded(), width: w, height: h))
        let p = context.data!.assumingMemoryBound(to: UInt8.self)
        return [Int(p[0]), Int(p[1]), Int(p[2])]
    }
}
