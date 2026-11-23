import Foundation
import ImageIO
import Darwin
import OSLog

enum HeadlessRenderer {
    private static let log = Logger(subsystem: "com.roccobot.craftlook", category: "render")

    static func render(_ file: URL, maxSide: Int, tools: URL, deadline: DispatchTime = .now() + 12) -> CGImage? {
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
            let input = scratch.appendingPathComponent("craftlook-document." + ext)
            let output = scratch.appendingPathComponent("craftlook-output.png")
            phase = "input"
            try fm.copyItem(at: file, to: input)
            if ext == "svg", let data = try? Data(contentsOf: file) {
                try SVGResource.write(SVGResource.contents(in: data, nextTo: file, limit: RenderXPC.imageLimit),
                                      to: scratch, limit: RenderXPC.imageLimit)
            }
            func run(_ args: [String]) throws -> Bool {
                try launch(executable, args, in: scratch, deadline: deadline, name: name)
            }

            let side = min(2048, max(256, maxSide))
            phase = "process"
            switch ext {
            case "figcraft": guard try run(["render", input.path, "-o", output.path, "--scale", "1"]) else { return nil }
            case "designcraft":
                guard try run(["run", "--in", input.path, "--scale", "2", "--export", output.path]) else { return nil }
            case "vectorcraft":
                guard try run(["--safe-mode", "convert", input.path, output.path, "--artboard", "0", "--scale", "2"])
                else { return nil }
            case "svg":
                guard try run(["--safe-mode", "convert", input.path, output.path, "--scale", svgScale(input, maxSide: side)])
                else { return nil }
            case "sc", "solidcraft":
                guard try run(["snapshot", input.path, "--out", output.path, "--width", "\(side)",
                               "--height", "\(side * 3 / 4)", "--no-grid", "--no-axes"]) else { return nil }
            case "fcproj":
                let film = try FilmProject(input)
                var project = input
                if !film.missing.isEmpty {
                    let fixed = scratch.appendingPathComponent("relinked.fcproj")
                    let script = try film.placeholders(in: scratch)
                    if try run(["--project", input.path, "--save-as", fixed.path, "run", script.path]) { project = fixed }
                }
                // What still can't be read, sound included, mustn't cost the picture.
                guard try run(["--project", project.path, "render", "--seconds", film.playhead, "--out", output.path,
                               "--scale", side > 960 ? "1" : "0.5", "--allow-offline"]) else {
                    let fit = Double(side) / Double(max(film.width, film.height))
                    return try Drawing.placeholder(width: max(1, Int(Double(film.width) * fit)),
                                                   height: max(1, Int(Double(film.height) * fit)), movie: true)
                }
            case "mcraft":
                let cube = min(1024, side)
                guard try run(["render", input.path, output.path, "--size", "\(cube)x\(cube)"]) else { return nil }
            case "ecproj", "ecprojx":
                guard try run(["--project", input.path, "render-frame", "--max-side", "\(side)", "--out", output.path])
                else { return nil }
            default:
                let texture = min(720, side)
                guard try run(["render", input.path, output.path, "--size", "\(texture)x\(texture * 3 / 4)",
                               "--samples", "1", "--bounces", "2", "--cpu"]) else { return nil }
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

    /// Runs a renderer until it ends or the deadline passes; whether it ended with status 0. Its error
    /// output goes to a file in the scratch folder, whose end is logged when the render fails.
    private static func launch(_ executable: URL, _ args: [String], in scratch: URL, deadline: DispatchTime,
                               name: String) throws -> Bool {
        let errors = scratch.appendingPathComponent("craftlook-stderr.txt")
        FileManager.default.createFile(atPath: errors.path, contents: nil, attributes: [.posixPermissions: 0o600])
        let errorOutput = try FileHandle(forWritingTo: errors)
        defer { try? errorOutput.close() }
        let process = Process()
        process.executableURL = executable
        process.arguments = args
        process.currentDirectoryURL = scratch
        process.environment = ["HOME": scratch.path, "TMPDIR": scratch.path, "PATH": "/usr/bin:/bin",
                               "VECTORCRAFT_NO_PREFS": "1"]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errorOutput
        let ended = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in ended.signal() }
        try process.run()
        if ended.wait(timeout: deadline) == .timedOut {
            process.terminate()
            if ended.wait(timeout: .now() + 0.25) == .timedOut { _ = kill(process.processIdentifier, SIGKILL) }
            process.waitUntilExit()
            log.error("\(name, privacy: .public) timed out\(tail(errors), privacy: .public)")
            return false
        }
        guard process.terminationStatus == 0 else {
            log.error("\(name, privacy: .public) exited with status \(process.terminationStatus)\(tail(errors), privacy: .public)")
            return false
        }
        return true
    }

    /// The last few hundred bytes a renderer wrote to its error output, for the log.
    private static func tail(_ file: URL) -> String {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return "" }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        try? handle.seek(toOffset: size > 600 ? size - 600 : 0)
        let text = String(decoding: (try? handle.readToEnd()) ?? Data(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "" : ": " + text
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

}

/// What the preview needs from a FilmCraft project (.fcproj, JSON): the playhead of the active sequence,
/// its frame size, and the media files that can't be read here, with their picture size.
struct FilmProject {
    struct Media { let item: Int; let width: Int; let height: Int; let movie: Bool }
    let playhead: String
    let width: Int, height: Int
    let missing: [Media]

    init(_ file: URL) throws {
        guard let data = try? Data(contentsOf: file, options: .mappedIfSafe),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let project = root["project"] as? [String: Any] else { throw ReadError.invalid }
        let view = root["view"] as? [String: Any]
        let items = project["items"] as? [String: Any] ?? [:]
        let active = view?["active_sequence"] as? Int
        // FilmCraft counts time in ticks of 1/254,016,000,000 of a second, as Premiere Pro does.
        // A project often opens on black, its playhead on a picture.
        if let active, let ticks = (view?["playheads"] as? [String: Any])?[String(active)] as? Double,
           ticks.isFinite, ticks >= 0 {
            playhead = String(format: "%.3f", ticks / 254_016_000_000)
        } else {
            playhead = "0"
        }
        let sequence = active.flatMap { items[String($0)] as? [String: Any] }
        let settings = ((sequence?["kind"] as? [String: Any])?["Sequence"] as? [String: Any])?["settings"] as? [String: Any]
        let frame = (settings?["width"] as? Int ?? 1920, settings?["height"] as? Int ?? 1080)
        (width, height) = (1...16384).contains(frame.0) && (1...16384).contains(frame.1) ? frame : (1920, 1080)
        missing = items.values.prefix(10_000).compactMap { value in
            guard let item = value as? [String: Any], let id = item["id"] as? Int,
                  let media = (item["kind"] as? [String: Any])?["Media"] as? [String: Any],
                  let path = ((media["media"] as? [String: Any])?["File"] as? [String: Any])?["path"] as? String,
                  let info = media["info"] as? [String: Any], let video = info["video"] as? [String: Any],
                  let w = video["width"] as? Int, let h = video["height"] as? Int,
                  (1...8192).contains(w), (1...8192).contains(h) else { return nil }
            // Inside the sandbox, a file next to the project is as unreadable as a missing one.
            guard media["offline"] as? Bool == true || !FileManager.default.isReadableFile(atPath: path) else { return nil }
            return Media(item: id, width: w, height: h, movie: info["kind"] as? String == "Movie")
        }
    }

    /// Writes a placeholder picture of each missing medium's size and the FilmCraft script that
    /// relinks the medium to it, so the placeholder takes the medium's place, size and motion.
    func placeholders(in folder: URL) throws -> URL {
        var lines: [String] = []
        for media in missing.prefix(64) {
            let picture = folder.appendingPathComponent("missing-\(media.item).png")
            guard let png = RenderXPC.png(try Drawing.placeholder(width: media.width, height: media.height, movie: media.movie))
            else { throw ReadError.limit }
            try png.write(to: picture)
            let params: [String: Any] = ["item": media.item, "path": picture.path, "force": true, "relinkOthers": false]
            let line = try JSONSerialization.data(withJSONObject: ["id": "media.relink", "params": params])
            lines.append(String(decoding: line, as: UTF8.self))
        }
        let script = folder.appendingPathComponent("relink.jsonl")
        try (lines.joined(separator: "\n") + "\n").write(to: script, atomically: true, encoding: .utf8)
        return script
    }
}
