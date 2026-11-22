import Foundation
import CoreGraphics

/// Sends every file to the renderer service twice, all requests at once, as Finder does with a folder,
/// and expects a picture for each: the service queues what it can't render yet.
@main struct ServiceCheck {
    static func main() {
        let service = CommandLine.arguments[1]
        let files = CommandLine.arguments.dropFirst(2).map { URL(fileURLWithPath: $0) }
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
            } else {
                print("\(file.lastPathComponent): nessuna immagine")
                failed += 1
            }
        }
        print("\(requests.count - failed) richieste su \(requests.count) riuscite in parallelo")
        exit(failed == 0 ? 0 : 1)
    }
}
