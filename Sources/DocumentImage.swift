import Foundation
import ImageIO
import UniformTypeIdentifiers

enum DocumentImage {
    private static let imageLimit = 32 << 20
    private static let vectorLimit = 64 << 20

    static func load(_ url: URL, maxSide: Int = 2048) throws -> CGImage {
        switch url.pathExtension.lowercased() {
        case "psd":
            let file = try FileHandle(forReadingFrom: url)
            defer { try? file.close() }
            guard try readAt(file, 0, 6) == Data([56, 66, 80, 83, 0, 1]),
                  let source = CGImageSourceCreateWithURL(url as CFURL, nil)
            else { throw ReadError.invalid }
            return try image(source, maxSide: maxSide)
        case "figcraft":
            return try zipped(url, marker: "document.json", images: ["thumbnail.png"], maxSide: maxSide)
        case "designcraft":
            return try zipped(url, marker: "document.json", images: ["preview.png"], maxSide: maxSide)
        case "tcraft":
            return try zipped(url, marker: "project.json", images: ["thumbnail.png"], maxSide: maxSide)
        case "pcraft":
            let paths = ["composite/full.png", "composite/preview.png", "thumb.png"]
            if try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true {
                let root = url.resolvingSymlinksInPath().standardizedFileURL.path
                func child(_ path: String) throws -> URL {
                    let entry = url.appendingPathComponent(path).resolvingSymlinksInPath().standardizedFileURL
                    guard entry.path == root + "/" + path,
                          try entry.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true
                    else { throw ReadError.invalid }
                    return entry
                }
                _ = try child("manifest.json")
                for path in paths {
                    if let entry = try? child(path),
                       let bytes = try? prefix(entry, limit: imageLimit, whole: true),
                       let pic = try? decode(bytes, maxSide: maxSide) { return pic }
                }
                throw ReadError.unavailable
            }
            return try zipped(url, marker: "manifest.json", images: paths, maxSide: maxSide)
        case "vectorcraft":
            let data = try prefix(url, limit: vectorLimit)
            let isGzip = data.starts(with: [0x1f, 0x8b])
            let bytes = isGzip ? try expand(data, window: 31, limit: vectorLimit, prefix: true) : data
            let end = try jsonEnd(bytes)
            let obj = try JSONSerialization.jsonObject(with: bytes.prefix(end))
            guard let root = obj as? [String: Any],
                  ["vectorcraft", "drawcraft"].contains(root["format"] as? String ?? ""),
                  root["version"] is Int else { throw ReadError.invalid }
            if let member = root["pdf"] as? [String: Any],
               member["mime"] as? String == "application/pdf",
               let pdf = pdfData(member, bytes: bytes, jsonEnd: end),
               let rendered = drawPDF(pdf, maxSide: maxSide) { return rendered }
            guard let p = root["preview"] as? [String: Any],
                  let decoded = inlineData(p) else { throw ReadError.unavailable }
            return try decode(decoded, maxSide: maxSide)
        default:
            throw ReadError.unavailable
        }
    }

    private static func inlineData(_ member: [String: Any]) -> Data? {
        guard let encoded = member["data"] as? String,
              encoded.utf8.count <= (imageLimit + 2) / 3 * 4 else { return nil }
        return Data(base64Encoded: encoded)
    }

    private static func pdfData(_ member: [String: Any], bytes: Data, jsonEnd: Int) -> Data? {
        if let inline = inlineData(member) { return inline }
        let marker = Data([10, 0] + Array("VCBLOBS".utf8) + [0])
        guard let blob = member["blob"] as? [Int], blob.count == 2,
              bytes.dropFirst(jsonEnd).starts(with: marker) else { return nil }
        let base = jsonEnd + marker.count
        let (offset, length) = (blob[0], blob[1])
        guard offset >= 0, length > 0, length <= imageLimit,
              length <= bytes.count - base, offset <= bytes.count - base - length else { return nil }
        return bytes.subdata(in: (base + offset)..<(base + offset + length))
    }

    private static func drawPDF(_ bytes: Data, maxSide: Int) -> CGImage? {
        guard bytes.starts(with: "%PDF-".utf8),
              let data = CGDataProvider(data: bytes as CFData),
              let document = CGPDFDocument(data),
              let page = document.page(at: 1) else { return nil }
        let box = page.getBoxRect(.cropBox)
        let turns = abs(page.rotationAngle % 180) == 90
        let (w, h) = turns ? (box.height, box.width) : (box.width, box.height)
        guard w.isFinite, h.isFinite, w > 0, h > 0 else { return nil }
        let width = max(1, Int((w / max(w, h) * CGFloat(maxSide)).rounded()))
        let height = max(1, Int((h / max(w, h) * CGFloat(maxSide)).rounded()))
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let bounds = CGRect(x: 0, y: 0, width: w, height: h)
        ctx.scaleBy(x: CGFloat(width) / w, y: CGFloat(height) / h)
        ctx.concatenate(page.getDrawingTransform(.cropBox, rect: bounds, rotate: 0, preserveAspectRatio: true))
        ctx.drawPDFPage(page)
        return ctx.makeImage()
    }

    private static func prefix(_ url: URL, limit: Int, whole: Bool = false) throws -> Data {
        let f = try FileHandle(forReadingFrom: url)
        defer { try? f.close() }
        let size = try f.seekToEnd()
        guard !whole || size <= UInt64(limit) else { throw ReadError.limit }
        return try readAt(f, 0, Int(min(UInt64(limit), size)))
    }

    private static func zipped(_ url: URL, marker: String, images: [String], maxSide: Int) throws -> CGImage {
        let zip = try ZipPreview(url: url, names: Set(images + [marker]))
        guard zip.members[marker] != nil else { throw ReadError.invalid }
        for path in images {
            if let bytes = try? zip.image(path, limit: imageLimit),
               let pic = try? decode(bytes, maxSide: maxSide) { return pic }
        }
        throw ReadError.unavailable
    }

    private static func jsonEnd(_ data: Data) throws -> Int {
        var depth = 0, quoted = false, escaped = false, started = false
        for (i, byte) in data.enumerated() {
            if !started {
                if [9, 10, 13, 32].contains(byte) { continue }
                guard byte == 123 else { throw ReadError.invalid }
                started = true
            }
            if quoted {
                if escaped { escaped = false }
                else if byte == 92 { escaped = true }
                else if byte == 34 { quoted = false }
            } else {
                switch byte {
                case 34: quoted = true
                case 123, 91: depth += 1
                case 125, 93:
                    depth -= 1
                    if depth == 0 { return i + 1 }
                default: break
                }
                guard depth <= 256 else { throw ReadError.limit }
            }
        }
        throw ReadError.invalid
    }

    private static func decode(_ bytes: Data, maxSide: Int) throws -> CGImage {
        guard let src = CGImageSourceCreateWithData(bytes as CFData, nil),
              let type = CGImageSourceGetType(src) as String?,
              [UTType.png.identifier, UTType.jpeg.identifier].contains(type) else { throw ReadError.invalid }
        return try image(src, maxSide: maxSide)
    }

    /// Draws an image over the whole of a Quick Look thumbnail context.
    static func fill(_ context: CGContext, with image: CGImage) {
        // The context holds contextSize × scale pixels with no scale transform, so a
        // rectangle in points would fill only its lower-left part on a Retina request.
        let pixels = CGRect(x: 0, y: 0, width: context.width, height: context.height)
        context.draw(image, in: context.convertToUserSpace(pixels))
    }

    static func image(_ src: CGImageSource, maxSide: Int) throws -> CGImage {
        guard let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int, w > 0, h > 0,
              h <= 100_000_000 / w else { throw ReadError.limit }
        let opts = [kCGImageSourceThumbnailMaxPixelSize: maxSide,
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary
        guard let picture = CGImageSourceCreateThumbnailAtIndex(src, 0, opts) else { throw ReadError.invalid }
        return picture
    }
}
