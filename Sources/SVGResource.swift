import Foundation

enum SVGResource {
    /// Same-folder file names referenced by href or xlink:href in `data`. Names with a path,
    /// a scheme, a query, a fragment, or `..` are ignored, so a link cannot leave the folder.
    static func names(in data: Data) -> [String] {
        let text = String(decoding: data, as: UTF8.self)
        guard let regex = try? NSRegularExpression(pattern: #"(?:xlink:)?href\s*=\s*["']([^"']+)["']"#,
                                                   options: [.caseInsensitive]) else { return [] }
        var seen = Set<String>()
        var names: [String] = []
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard match.numberOfRanges >= 2, let from = Range(match.range(at: 1), in: text) else { continue }
            let raw = String(text[from]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let name = localName(raw), seen.insert(name).inserted else { continue }
            names.append(name)
        }
        return names
    }

    /// A file name that stays in the same folder: no path, scheme, query, fragment, or parent.
    static func localName(_ raw: String) -> String? {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != ".", name != "..",
              !name.contains("/"), !name.contains("\\"), !name.contains(":"),
              !name.contains("?"), !name.contains("#"), !name.contains("\0") else { return nil }
        return name
    }

    /// Bytes of each readable same-folder resource next to `file`, up to `limit` each.
    static func contents(in data: Data, nextTo file: URL, limit: Int) -> [String: Data] {
        let folder = file.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL
        var result: [String: Data] = [:]
        for name in names(in: data) {
            let resolved = folder.appendingPathComponent(name).resolvingSymlinksInPath().standardizedFileURL
            guard resolved.deletingLastPathComponent() == folder,
                  resolved.lastPathComponent == name,
                  let props = try? resolved.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  props.isRegularFile == true,
                  let size = props.fileSize, (1...limit).contains(size),
                  let bytes = try? Data(contentsOf: resolved), bytes.count == size else { continue }
            result[name] = bytes
        }
        return result
    }

    /// Writes already-collected resources into `directory`, after checking the names again.
    static func write(_ resources: [String: Data], to directory: URL, limit: Int) throws {
        let folder = directory.resolvingSymlinksInPath().standardizedFileURL
        for (name, bytes) in resources {
            guard localName(name) == name, (1...limit).contains(bytes.count) else { continue }
            let dest = folder.appendingPathComponent(name).standardizedFileURL
            guard dest.deletingLastPathComponent() == folder else { continue }
            try bytes.write(to: dest)
        }
    }
}
