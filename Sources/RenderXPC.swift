import Foundation
import ImageIO
import UniformTypeIdentifiers
import OSLog

@objc protocol RenderServiceProtocol {
    func render(_ document: Data, fileExtension: String, maxSide: Int,
                resources: [String: Data], reply: @escaping (Data?) -> Void)
}

enum RenderXPC {
    /// The bundled renderer of each extension: the CLI of the app that saves it. SVG files go to VectorCraft.
    static let renderers = [
        "figcraft": "figcraft", "designcraft": "designcraft", "vectorcraft": "vectorcraft", "svg": "vectorcraft",
        "tcraft": "texturecraft", "sc": "solidcraft", "solidcraft": "solidcraft", "fcproj": "filmcraft",
        "mcraft": "materialcraft", "ecproj": "effectcraft", "ecprojx": "effectcraft",
    ]

    static let supported = Set(renderers.keys)
    /// Formats whose saved image is only a small thumbnail: a large picture comes from the renderer first.
    static func rendersFirst(_ ext: String, maxSide: Int) -> Bool {
        ["figcraft", "designcraft"].contains(ext) && maxSide > 1024
    }
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

    /// The picture the thumbnail or preview extension shows for `file`: the renderer first when
    /// that is the large view, otherwise the image saved in the file, otherwise the renderer.
    static func picture(_ file: URL, maxSide: Int, service: String) throws -> CGImage {
        let ext = file.pathExtension.lowercased()
        // A render that has failed once is not tried again: before 0.5.1 a FigCraft or DesignCraft
        // file the renderer couldn't draw cost two full waits on Space.
        let first = rendersFirst(ext, maxSide: maxSide)
        if first, let image = render(file, maxSide: maxSide, service: service) { return image }
        if let embedded = try? DocumentImage.load(file, maxSide: maxSide) { return embedded }
        if !first, let image = render(file, maxSide: maxSide, service: service) { return image }
        throw ReadError.unavailable
    }

    /// The Helpers folder: first the copy inside this service (hard links to the app's one set of
    /// renderers, which the sandbox can run), then the app's Contents/Helpers.
    static func helpers(from bundle: URL = Bundle.main.bundleURL) -> URL? {
        let fm = FileManager.default
        func usable(_ tools: URL) -> URL? {
            fm.isExecutableFile(atPath: tools.appendingPathComponent("vectorcraft-cli").path) ? tools : nil
        }
        if let tools = usable(bundle.appendingPathComponent("Contents/Helpers", isDirectory: true)) { return tools }
        var url = bundle
        for _ in 0..<8 {
            url.deleteLastPathComponent()
            if let tools = usable(url.appendingPathComponent("Helpers", isDirectory: true)) { return tools }
        }
        return nil
    }

    /// The picture the renderer service draws for `file`; `service` is the service's bundle identifier.
    static func render(_ file: URL, maxSide: Int, service: String) -> CGImage? {
        let ext = file.pathExtension.lowercased()
        guard supported.contains(ext),
              let props = try? file.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
              props.isRegularFile == true, let size = props.fileSize, (1...inputLimit).contains(size),
              let fh = try? FileHandle(forReadingFrom: file) else { return nil }
        defer { try? fh.close() }
        guard let document = try? readAt(fh, 0, size) else { return nil }
        let resources = ext == "svg" ? SVGResource.contents(in: document, nextTo: file, limit: imageLimit) : [:]

        let connection = NSXPCConnection(serviceName: service)
        connection.remoteObjectInterface = NSXPCInterface(with: RenderServiceProtocol.self)
        let result = RenderResult()
        connection.invalidationHandler = { result.finish(nil) }
        connection.interruptionHandler = { result.finish(nil) }
        connection.resume()
        defer { connection.invalidate() }

        let log = Logger(subsystem: "com.roccobot.craftlook", category: "xpc")
        guard let remote = connection.remoteObjectProxyWithErrorHandler({ error in
            log.error("Renderer connection failed: \(String(describing: error), privacy: .public)")
            result.finish(nil)
        }) as? RenderServiceProtocol else { return nil }
        remote.render(document, fileExtension: ext, maxSide: maxSide, resources: resources) { result.finish($0) }

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
