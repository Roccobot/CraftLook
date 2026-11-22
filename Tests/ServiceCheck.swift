import Foundation
import CoreGraphics

/// Sends every file to the renderer service twice, all requests at once, as Finder does with a folder,
/// and expects a picture for each: the service queues what it can't render yet.
@main struct ServiceCheck {
    static func main() {
        let service = CommandLine.arguments[1]
        let files = CommandLine.arguments.dropFirst(2).map { URL(fileURLWithPath: $0) }
            .filter { RenderXPC.supported.contains($0.pathExtension.lowercased()) }
        let requests = files + files
        var results = [(CGImage?, TimeInterval)](repeating: (nil, 0), count: requests.count)
        let lock = NSLock()
        let start = Date()
        DispatchQueue.concurrentPerform(iterations: requests.count) { index in
            let image = RenderXPC.render(requests[index], maxSide: 512, service: service)
            lock.lock()
            results[index] = (image, Date().timeIntervalSince(start))
            lock.unlock()
        }
        var failed = 0
        for (file, (image, seconds)) in zip(requests, results) {
            if let image {
                print(String(format: "%@: %d × %d, %.2f s", file.lastPathComponent, image.width, image.height, seconds))
                if file.lastPathComponent.hasPrefix("linked.") {
                    let aspect = Double(image.width) / Double(image.height)
                    if abs(aspect - 1200.0 / 2670.0) > 0.01 || max(image.width, image.height) != 512
                        || zip(pixel(image, 0.5, 690.0 / 2670.0), [0, 200, 40]).contains(where: { abs($0 - $1) > 16 }) {
                        print("\(file.lastPathComponent): anteprima SVG attesa 230 × 512 con il campione verde, ottenuta \(image.width) × \(image.height) \(pixel(image, 0.5, 690.0 / 2670.0))")
                        failed += 1
                    }
                }
            } else {
                print("\(file.lastPathComponent): nessuna immagine")
                failed += 1
            }
        }
        print("\(requests.count - failed) richieste su \(requests.count) riuscite in parallelo")
        exit(failed == 0 ? 0 : 1)
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
