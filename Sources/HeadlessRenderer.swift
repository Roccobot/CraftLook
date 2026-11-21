import Foundation
import ImageIO
import Darwin
import OSLog

enum HeadlessRenderer {
    private static let log = Logger(subsystem: "org.artcraftquicklook.local", category: "render")
    // The extension and its helpers share the app bundle. Only bundled renderers are executable.
    static func helpers(for provider: AnyClass) -> URL {
        Bundle(for: provider).bundleURL.appendingPathComponent("Contents/Helpers", isDirectory: true)
    }

    static func render(_ file: URL, maxSide: Int, tools: URL) -> CGImage? {
        let ext = file.pathExtension.lowercased()
        guard let name = ["figcraft": "figcraft", "designcraft": "designcraft",
                          "vectorcraft": "vectorcraft", "tcraft": "texturecraft"][ext] else { return nil }
        let executable = tools.appendingPathComponent(name + "-cli")
        let fm = FileManager.default
        guard let props = try? file.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
              props.isRegularFile == true, let bytes = props.fileSize, (1...(256 << 20)).contains(bytes)
        else { return nil }

        let scratch = fm.temporaryDirectory.appendingPathComponent("artcraft-" + UUID().uuidString, isDirectory: true)
        var phase = "scratch"
        do {
            try fm.createDirectory(at: scratch, withIntermediateDirectories: false,
                                   attributes: [.posixPermissions: 0o700])
            defer { try? fm.removeItem(at: scratch) }
            // A subprocess doesn't inherit the file access macOS granted for this individual request.
            let input = scratch.appendingPathComponent("document." + ext)
            let output = scratch.appendingPathComponent("preview.png")
            phase = "input"
            try fm.copyItem(at: file, to: input)

            let args: [String]
            switch ext {
            case "figcraft": args = ["render", input.path, "-o", output.path, "--scale", "1"]
            case "designcraft":
                args = ["run", "--in", input.path, "--scale", "2", "--export", output.path]
            case "vectorcraft":
                args = ["--safe-mode", "convert", input.path, output.path, "--artboard", "0", "--scale", "2"]
            default:
                let side = min(720, max(256, maxSide))
                args = ["render", input.path, output.path, "--size", "\(side)x\(side * 3 / 4)",
                        "--samples", "1", "--bounces", "2", "--cpu"]
            }

            let process = Process()
            process.executableURL = executable
            process.arguments = args
            process.currentDirectoryURL = scratch
            process.environment = ["HOME": scratch.path, "TMPDIR": scratch.path, "PATH": "/usr/bin:/bin",
                                   "VECTORCRAFT_NO_PREFS": "1"]
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice

            let ended = DispatchSemaphore(value: 0)
            process.terminationHandler = { _ in ended.signal() }
            phase = "process"
            try process.run()
            if ended.wait(timeout: .now() + 12) == .timedOut {
                process.terminate()
                if ended.wait(timeout: .now() + 0.25) == .timedOut { _ = kill(process.processIdentifier, SIGKILL) }
                process.waitUntilExit()
                log.error("\(name, privacy: .public) timed out")
                return nil
            }
            guard process.terminationStatus == 0 else {
                log.error("\(name, privacy: .public) exited with status \(process.terminationStatus)")
                return nil
            }
            phase = "output"
            let size = try output.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard (1...(32 << 20)).contains(size),
                  let source = CGImageSourceCreateWithURL(output as CFURL, nil) else { return nil }
            return try DocumentImage.image(source, maxSide: maxSide)
        } catch {
            log.error("\(name, privacy: .public) failed in \(phase, privacy: .public) (\(String(describing: error), privacy: .public))")
            return nil
        }
    }
}
