import Foundation
import CoreGraphics

@main struct HeadlessCheck {
    static func main() throws {
        if CommandLine.arguments[1] == "--timeout" { return try timeout() }
        let tools = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        for path in CommandLine.arguments.dropFirst(2) {
            let file = URL(fileURLWithPath: path)
            guard RenderXPC.renderers[file.pathExtension.lowercased()] != nil else { continue }
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
            // A tall SVG with a same-folder PNG must keep its aspect and show that picture, not a crop
            // or a missing-image placeholder.
            if file.lastPathComponent.hasPrefix("linked.") {
                let aspect = Double(image.width) / Double(image.height)
                if abs(aspect - 1200.0 / 2670.0) > 0.01 || max(image.width, image.height) != 2048 {
                    throw failure("\(file.lastPathComponent) non conserva il formato (\(image.width) × \(image.height))")
                }
                // The swatch is centred at (600, 690) in the 1200 × 2670 viewBox.
                if zip(pixel(image, 0.5, 690.0 / 2670.0), [0, 200, 40]).contains(where: { abs($0 - $1) > 16 }) {
                    throw failure("\(file.lastPathComponent) non mostra l'immagine collegata (\(pixel(image, 0.5, 690.0 / 2670.0)))")
                }
            }
            print(String(format: "%@: %d × %d, %.2f s", file.lastPathComponent, image.width, image.height, seconds))
        }
    }

    /// A renderer that outlives its deadline is stopped with everything it started: a fake
    /// MaterialCraft that leaves a child behind and then hangs, with a one-second deadline.
    static func timeout() throws {
        let fm = FileManager.default
        let folder = fm.temporaryDirectory.appendingPathComponent("craftlook-timeout-" + UUID().uuidString)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: folder) }
        let pidFile = folder.appendingPathComponent("child.pid")
        let fake = folder.appendingPathComponent("materialcraft-cli")
        try "#!/bin/sh\n/bin/sleep 30 &\necho $! > '\(pidFile.path)'\n/bin/sleep 30\n".write(to: fake, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fake.path)
        let project = folder.appendingPathComponent("cube.mcraft")
        try Data("{}".utf8).write(to: project)
        let start = Date()
        guard HeadlessRenderer.render(project, maxSide: 512, tools: folder, deadline: .now() + 1) == nil else {
            throw failure("Il renderer finto ha prodotto un'immagine")
        }
        guard Date().timeIntervalSince(start) < 5,
              let text = try? String(contentsOf: pidFile, encoding: .utf8),
              let child = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw failure("Il renderer finto non si è fermato in tempo")
        }
        usleep(200_000)
        if kill(child, 0) == 0 {
            kill(child, SIGKILL)
            throw failure("Il processo avviato dal renderer è ancora attivo dopo la scadenza")
        }
        print("timeout: renderer e processi figli fermati")
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
