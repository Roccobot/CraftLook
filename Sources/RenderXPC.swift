import Foundation
import ImageIO
import UniformTypeIdentifiers
import OSLog

@objc protocol RenderServiceProtocol {
    func render(_ document: Data, fileExtension: String, maxSide: Int,
                reply: @escaping (Data?) -> Void)
}

enum RenderXPC {
    static let supported: Set<String> = ["figcraft", "designcraft", "vectorcraft", "tcraft"]
    static let inputLimit = 256 << 20
    static let imageLimit = 32 << 20

    static func png(_ image: CGImage) -> Data? {
        let bytes = NSMutableData()
        guard let out = CGImageDestinationCreateWithData(bytes, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(out, image, nil)
        guard CGImageDestinationFinalize(out), bytes.length <= imageLimit else { return nil }
        return bytes as Data
    }

    static func render(_ file: URL, maxSide: Int, provider: AnyClass) -> CGImage? {
        let ext = file.pathExtension.lowercased()
        guard supported.contains(ext),
              let id = Bundle(for: provider).bundleIdentifier,
              let props = try? file.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
              props.isRegularFile == true, let size = props.fileSize, (1...inputLimit).contains(size),
              let fh = try? FileHandle(forReadingFrom: file) else { return nil }
        defer { try? fh.close() }
        guard let document = try? readAt(fh, 0, size) else { return nil }

        let connection = NSXPCConnection(serviceName: id + ".render")
        connection.remoteObjectInterface = NSXPCInterface(with: RenderServiceProtocol.self)
        let result = RenderResult()
        connection.invalidationHandler = { result.finish(nil) }
        connection.interruptionHandler = { result.finish(nil) }
        connection.resume()
        defer { connection.invalidate() }

        let log = Logger(subsystem: "org.artcraftquicklook.local", category: "xpc")
        guard let remote = connection.remoteObjectProxyWithErrorHandler({ error in
            log.error("Renderer connection failed: \(String(describing: error), privacy: .public)")
            result.finish(nil)
        }) as? RenderServiceProtocol else { return nil }
        remote.render(document, fileExtension: ext, maxSide: maxSide) { result.finish($0) }

        guard let bytes = result.wait(), bytes.count <= imageLimit,
              let image = CGImageSourceCreateWithData(bytes as CFData, nil) else { return nil }
        return try? DocumentImage.image(image, maxSide: maxSide)
    }
}

private final class RenderResult: @unchecked Sendable {
    private let lock = NSLock()
    private let done = DispatchSemaphore(value: 0)
    private var returned = false
    private var value: Data?

    func finish(_ value: Data?) {
        lock.lock()
        defer { lock.unlock() }
        guard !returned else { return }
        returned = true
        self.value = value
        done.signal()
    }

    func wait() -> Data? {
        guard done.wait(timeout: .now() + 14) == .success else { return nil }
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}
