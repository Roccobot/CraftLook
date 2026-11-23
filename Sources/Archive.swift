import Foundation
import zlib

enum ReadError: LocalizedError {
    case invalid, limit, unavailable
    var errorDescription: String? {
        switch self {
        case .invalid: "The document or its image is not valid."
        case .limit: "The document exceeds the preview limits."
        case .unavailable: "The document holds no usable preview."
        }
    }
}

func readAt(_ file: FileHandle, _ offset: UInt64, _ count: Int) throws -> Data {
    try file.seek(toOffset: offset)
    let data = try file.read(upToCount: count) ?? Data()
    guard data.count == count else { throw ReadError.invalid }
    return data
}

extension Data {
    func u16(_ p: Int) -> Int { Int(self[p]) | Int(self[p + 1]) << 8 }
    func u32(_ p: Int) -> Int { u16(p) | u16(p + 2) << 16 }
}

func expand(_ input: Data, window: Int32, limit: Int, prefix: Bool = false) throws -> Data {
    var stream = z_stream()
    guard inflateInit2_(&stream, window, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
        throw ReadError.invalid
    }
    defer { inflateEnd(&stream) }
    return try input.withUnsafeBytes { source in
        stream.next_in = UnsafeMutablePointer(mutating: source.bindMemory(to: UInt8.self).baseAddress)
        stream.avail_in = UInt32(input.count)
        var out = Data()
        var buffer = [UInt8](repeating: 0, count: 65_536)
        while true {
            let capacity = min(buffer.count, limit + 1 - out.count)
            let status = buffer.withUnsafeMutableBufferPointer { chunk in
                stream.next_out = chunk.baseAddress
                stream.avail_out = UInt32(capacity)
                return inflate(&stream, Z_NO_FLUSH)
            }
            out.append(contentsOf: buffer.prefix(capacity - Int(stream.avail_out)))
            if out.count > limit {
                if prefix { return Data(out.prefix(limit)) }
                throw ReadError.limit
            }
            if status == Z_STREAM_END {
                guard prefix || stream.avail_in == 0 else { throw ReadError.invalid }
                return out
            }
            guard status == Z_OK else { throw ReadError.invalid }
        }
    }
}

struct ZipPreview {
    struct Member {
        let name: String, flags: Int, method: Int, crc: Int
        let compressed: Int, expanded: Int, offset: Int
    }
    private let file: FileHandle
    private let centralOffset: Int
    private(set) var members: [String: Member] = [:]

    init(url: URL, names: Set<String>) throws {
        file = try FileHandle(forReadingFrom: url)
        let size = try file.seekToEnd()
        guard size >= 22, size <= UInt64(Int.max) else { throw ReadError.invalid }
        let n = Int(min(size, 65_557))
        let tail = try readAt(file, size - UInt64(n), n)
        guard let end = stride(from: n - 22, through: 0, by: -1).first(where: {
            tail.u32($0) == 0x06054b50 && $0 + 22 + tail.u16($0 + 20) == n
        }) else { throw ReadError.invalid }
        let count = tail.u16(end + 10), length = tail.u32(end + 12)
        centralOffset = tail.u32(end + 16)
        guard count < 65_535, length <= 16 << 20,
              tail.u16(end + 4) == 0, tail.u16(end + 6) == 0, tail.u16(end + 8) == count,
              centralOffset + length == Int(size) - n + end else { throw ReadError.limit }
        let cd = try readAt(file, UInt64(centralOffset), length)
        var p = 0
        for _ in 0..<count {
            guard p + 46 <= length, cd.u32(p) == 0x02014b50 else { throw ReadError.invalid }
            let nameLength = cd.u16(p + 28)
            let next = p + 46 + nameLength + cd.u16(p + 30) + cd.u16(p + 32)
            guard next <= length else { throw ReadError.invalid }
            let bytes = cd[(p + 46)..<(p + 46 + nameLength)]
            if let name = String(data: bytes, encoding: .utf8), names.contains(name) {
                guard members[name] == nil else { throw ReadError.invalid }
                members[name] = Member(name: name, flags: cd.u16(p + 8), method: cd.u16(p + 10),
                    crc: cd.u32(p + 16), compressed: cd.u32(p + 20), expanded: cd.u32(p + 24),
                    offset: cd.u32(p + 42))
            }
            p = next
        }
        guard p == length else { throw ReadError.invalid }
    }

    func image(_ name: String, limit: Int) throws -> Data {
        guard let m = members[name] else { throw ReadError.unavailable }
        guard m.expanded <= limit, m.compressed <= limit, m.expanded > 0,
              m.offset + 30 <= centralOffset, m.flags & 1 == 0 else { throw ReadError.limit }
        let header = try readAt(file, UInt64(m.offset), 30)
        let start = m.offset + 30 + header.u16(26) + header.u16(28)
        guard header.u32(0) == 0x04034b50, header.u16(6) == m.flags,
              header.u16(8) == m.method, start + m.compressed <= centralOffset else { throw ReadError.invalid }
        let localName = try readAt(file, UInt64(m.offset + 30), header.u16(26))
        guard localName == Data(m.name.utf8) else { throw ReadError.invalid }
        let bytes = try readAt(file, UInt64(start), m.compressed)
        let result: Data
        switch m.method {
        case 0: result = bytes
        case 8: result = try expand(bytes, window: -15, limit: m.expanded)
        default: throw ReadError.invalid
        }
        guard result.count == m.expanded, result.withUnsafeBytes({
            crc32(0, $0.bindMemory(to: UInt8.self).baseAddress, UInt32(result.count))
        }) == UInt(m.crc) else { throw ReadError.invalid }
        return result
    }
}
