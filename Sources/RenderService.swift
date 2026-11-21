import Foundation
import OSLog

private final class Renderer: NSObject, RenderServiceProtocol, NSXPCListenerDelegate {
    private let jobs = DispatchQueue(label: "org.artcraftquicklook.local.render")
    private let available = DispatchSemaphore(value: 1)

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard connection.effectiveUserIdentifier == geteuid() else { return false }
        connection.exportedInterface = NSXPCInterface(with: RenderServiceProtocol.self)
        connection.exportedObject = self
        connection.resume()
        return true
    }

    func render(_ document: Data, fileExtension: String, maxSide: Int,
                reply: @escaping (Data?) -> Void) {
        guard RenderXPC.supported.contains(fileExtension),
              (1...RenderXPC.inputLimit).contains(document.count),
              (1...2048).contains(maxSide),
              available.wait(timeout: .now()) == .success else {
            reply(nil)
            return
        }
        jobs.async {
            defer { self.available.signal() }
            let fm = FileManager.default
            let temp = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            do {
                try fm.createDirectory(at: temp, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
                defer { try? fm.removeItem(at: temp) }
                let file = temp.appendingPathComponent("project." + fileExtension)
                try document.write(to: file)
                let tools = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers", isDirectory: true)
                let image = HeadlessRenderer.render(file, maxSide: maxSide, tools: tools)
                reply(image.flatMap(RenderXPC.png))
            } catch {
                Logger(subsystem: "org.artcraftquicklook.local", category: "service")
                    .error("Renderer input failed (\((error as NSError).code))")
                reply(nil)
            }
        }
    }
}

@main struct RenderService {
    static func main() {
        let renderer = Renderer()
        let server = NSXPCListener.service()
        server.delegate = renderer
        withExtendedLifetime(renderer) { server.resume() }
    }
}
