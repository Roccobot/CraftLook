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
        guard let name = RenderXPC.renderers[ext] else { return nil }
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

            let side = min(2048, max(256, maxSide))
            let args: [String]
            switch ext {
            case "figcraft": args = ["render", input.path, "-o", output.path, "--scale", "1"]
            case "designcraft":
                args = ["run", "--in", input.path, "--scale", "2", "--export", output.path]
            case "vectorcraft":
                args = ["--safe-mode", "convert", input.path, output.path, "--artboard", "0", "--scale", "2"]
            case "svg":
                args = ["--safe-mode", "convert", input.path, output.path, "--scale", svgScale(input, maxSide: side)]
            case "sc", "solidcraft":
                args = ["snapshot", input.path, "--out", output.path, "--width", "\(side)",
                        "--height", "\(side * 3 / 4)", "--no-grid", "--no-axes"]
            case "fcproj":
                args = ["--project", input.path, "render", "--seconds", playhead(input), "--out", output.path,
                        "--scale", side > 960 ? "1" : "0.5"]
            case "mcraft":
                let cube = min(1024, side)
                args = ["render", input.path, output.path, "--size", "\(cube)x\(cube)"]
            case "ecproj", "ecprojx":
                args = ["--project", input.path, "render-frame", "--max-side", "\(side)", "--out", output.path]
            default:
                let texture = min(720, side)
                args = ["render", input.path, output.path, "--size", "\(texture)x\(texture * 3 / 4)",
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

    /// The VectorCraft scale that brings an SVG's longest side to maxSide, from the width, height or
    /// viewBox of its root element; 2 when they don't say. VectorCraft exports one pixel per SVG unit.
    static func svgScale(_ file: URL, maxSide: Int) -> String {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return "2" }
        defer { try? handle.close() }
        let head = String(decoding: (try? handle.read(upToCount: 64 << 10)) ?? Data(), as: UTF8.self)
        guard let open = head.range(of: "<svg", options: .caseInsensitive),
              let close = head[open.upperBound...].firstIndex(of: ">") else { return "2" }
        let tag = String(head[open.upperBound..<close])
        func attribute(_ name: String) -> String? {
            guard let match = tag.range(of: "\\s\(name)\\s*=\\s*([\"'])([^\"']*)\\1", options: .regularExpression)
            else { return nil }
            let text = tag[match]
            return text.split(whereSeparator: { $0 == "\"" || $0 == "'" }).dropFirst().first.map(String.init)
        }
        // CSS units, 96 to the inch: what a percentage or an em is relative to isn't known here.
        let units: [String: Double] = ["": 1, "px": 1, "pt": 4.0 / 3, "pc": 16, "in": 96, "cm": 96 / 2.54, "mm": 96 / 25.4]
        func length(_ text: String?) -> Double? {
            guard let text, let number = text.range(of: "^\\s*[0-9.]+", options: .regularExpression),
                  let value = Double(text[number].trimmingCharacters(in: .whitespaces)),
                  let unit = units[text[number.upperBound...].trimmingCharacters(in: .whitespaces).lowercased()]
            else { return nil }
            return value * unit
        }
        var sides = [length(attribute("width")), length(attribute("height"))].compactMap { $0 }
        if sides.count < 2, let box = attribute("viewBox") {
            let values = box.split(whereSeparator: { $0 == " " || $0 == "," }).compactMap { Double($0) }
            if values.count == 4 { sides = [values[2], values[3]] }
        }
        guard let longest = sides.max(), longest.isFinite, longest > 0 else { return "2" }
        return String(format: "%.4f", min(64, max(1.0 / 64, Double(maxSide) / longest)))
    }

    /// The time, in seconds, of the playhead saved in the active sequence of a FilmCraft project;
    /// 0 when the project doesn't say. A project often opens on black, its playhead on a picture.
    static func playhead(_ file: URL) -> String {
        guard let data = try? Data(contentsOf: file, options: .mappedIfSafe),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let view = root["view"] as? [String: Any],
              let active = view["active_sequence"] as? Int,
              let heads = view["playheads"] as? [String: Any],
              let ticks = heads[String(active)] as? Double, ticks.isFinite, ticks >= 0
        else { return "0" }
        // FilmCraft counts time in ticks of 1/254,016,000,000 of a second, as Premiere Pro does.
        return String(format: "%.3f", ticks / 254_016_000_000)
    }
}
