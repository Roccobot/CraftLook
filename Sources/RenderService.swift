import Foundation
import OSLog

private final class Renderer: NSObject, RenderServiceProtocol, NSXPCListenerDelegate {
    // Finder asks for many thumbnails at once: requests wait for one of two renderer slots
    // instead of being turned away, until the time a renderer would have had runs out.
    private let jobs = DispatchQueue(label: "com.roccobot.craftlook.render", attributes: .concurrent)
    private let slots = DispatchSemaphore(value: 2)
    private let log = Logger(subsystem: "com.roccobot.craftlook", category: "service")

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard connection.effectiveUserIdentifier == geteuid() else { return false }
        connection.exportedInterface = NSXPCInterface(with: RenderServiceProtocol.self)
        connection.exportedObject = self
        connection.resume()
        return true
    }

    func render(_ document: Data, fileExtension: String, maxSide: Int,
                resources: [String: Data], reply: @escaping (Data?) -> Void) {
        guard RenderXPC.supported.contains(fileExtension),
              (1...RenderXPC.inputLimit).contains(document.count),
              (1...2048).contains(maxSide) else {
            reply(nil)
            return
        }
        // The client waits 14 seconds from its request; a render has to end within 12 of it, and a
        // request that gets a slot with less than 3 seconds left gives it back instead of starting a
        // renderer that would be stopped at once.
        let deadline = DispatchTime.now() + 12
        guard let tools = RenderXPC.helpers() else {
            log.error("Renderer helpers are missing")
            reply(nil)
            return
        }
        jobs.async {
            guard self.slots.wait(timeout: deadline - 3) == .success else {
                self.log.error("Renderer queue full until the deadline")
                reply(nil)
                return
            }
            defer { self.slots.signal() }
            let fm = FileManager.default
            let temp = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            do {
                try fm.createDirectory(at: temp, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
                defer { try? fm.removeItem(at: temp) }
                let file = temp.appendingPathComponent("craftlook-input." + fileExtension)
                try document.write(to: file)
                try SVGResource.write(resources, to: temp, limit: RenderXPC.imageLimit)
                let image = HeadlessRenderer.render(file, maxSide: maxSide, tools: tools, deadline: deadline)
                reply(image.flatMap(RenderXPC.png))
            } catch {
                self.log.error("Renderer input failed (\((error as NSError).code))")
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
