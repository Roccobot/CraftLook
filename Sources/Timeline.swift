import Foundation
import CoreGraphics

/// The timeline of a SoundCraft session (.scraft, JSON), drawn as a diagram: one lane per track,
/// its clips where and as long as they play, MIDI notes inside instrument clips, markers and playhead.
/// SoundCraft counts time in samples at the session's rate and MIDI notes in ticks of 1/960 of a beat.
/// The card is always square, like a Finder thumbnail: the lanes share its height, whatever the session.
enum Timeline {
    private struct Clip { let start, length: Double; let name: String; let muted: Bool
                          let fadeIn, fadeOut: Double; let notes: [(start: Double, length: Double, pitch: Int)] }
    private struct Track { let name: String; let color: CGColor; let muted: Bool; let clips: [Clip] }
    private static let ticksPerBeat = 960.0
    private static let side: CGFloat = 1600
    /// The longest session drawn: a day. Times past it are drawn at its end, so that no value a file
    /// holds can push a conversion to Int out of range (choice Scraft-01: a session with impossible
    /// values is still drawn, with each value brought into a sensible range).
    private static let longestSession = 86_400.0

    /// `value` brought into `range`: what a session file says is never trusted to be sensible.
    private static func bounded(_ value: Double, _ range: ClosedRange<Double>) -> Double {
        min(range.upperBound, max(range.lowerBound, value))
    }

    static func image(_ data: Data, maxSide: Int) throws -> CGImage {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              root["format_version"] is Int, let rawTracks = root["tracks"] as? [[String: Any]],
              let rawRate = number(root["sample_rate"]), rawRate > 0 else { throw ReadError.invalid }
        let rate = bounded(rawRate, 8_000...768_000)
        let tempo = root["tempo"] as? [String: Any]
        let bpm = bounded(number((tempo?["tempos"] as? [[String: Any]])?.first?["bpm"]).flatMap { $0 > 0 ? $0 : nil } ?? 120, 10...999)
        let meter = (tempo?["meters"] as? [[String: Any]])?.first
        let beats = bounded(number(meter?["numerator"]).flatMap { $0 > 0 ? $0 : nil } ?? 4, 1...64)
        let unit = bounded(number(meter?["denominator"]).flatMap { $0 > 0 ? $0 : nil } ?? 4, 1...64)
        let limit = longestSession * rate
        let samplesPerTick = 60 / bpm * rate / ticksPerBeat

        let tracks = rawTracks.prefix(256).compactMap { track(from: $0, samplesPerTick: samplesPerTick, limit: limit) }.prefix(64)
        let markers = ((root["markers"] as? [[String: Any]]) ?? []).prefix(512).compactMap { m -> (Double, String)? in
            guard let start = number(m["start"]), start >= 0 else { return nil }
            return (min(start, limit), m["name"] as? String ?? "")
        }
        let playhead = number((root["edit"] as? [String: Any])?["playhead"]).map { min($0, limit) }
        let end = max(rate, ([0] + tracks.flatMap { $0.clips.map { $0.start + $0.length } } + markers.map { $0.0 }).max()!) * 1.03

        // The layout, in points of a square card 1600 points wide: the lanes fill the height under the ruler,
        // up to 240 points each, and a few tall lanes sit in the middle of it.
        let width = side, height = side
        let header: CGFloat = 96, ruler: CGFloat = 36, left: CGFloat = 232, right: CGFloat = 28, bottom: CGFloat = 28
        let area = height - header - ruler - bottom
        let lane = min(240, area / CGFloat(max(tracks.count, 1)))
        let pixels = CGFloat(min(2048, max(16, maxSide)))
        let scale = pixels / side
        let context = try Drawing.canvas(width: Int(pixels), height: Int(pixels), scale: scale)
        let readable = 11 * scale >= 5
        let span = width - left - right
        func x(_ sample: Double) -> CGFloat { left + CGFloat(sample / end) * span }

        Drawing.roundedRect(context, CGRect(x: 0, y: 0, width: width, height: height), radius: 28,
                            fill: Drawing.color(0x1B, 0x1D, 0x21))
        let top = header + ruler, lanes = top + (area - lane * CGFloat(tracks.count)) / 2
        let white = Drawing.color(0xF2, 0xF2, 0xF2), grey = Drawing.color(0x9A, 0xA0, 0xA8)
        if readable {
            Drawing.text(context, root["name"] as? String ?? "", at: CGPoint(x: 32, y: 22), size: 34, bold: true,
                         color: white, width: width - 420)
            let seconds = Int((end / 1.03 / rate).rounded())
            let facts = String(format: "%g BPM  ·  %g/%g  ·  %g kHz  ·  %d:%02d", bpm, beats, unit, rate / 1000,
                               seconds / 60, seconds % 60)
            Drawing.text(context, facts, at: CGPoint(x: 32, y: 64), size: 17, color: grey, width: width - 64)
        }

        // Bars on the ruler, a label every few so that they keep apart.
        let bar = beats * 4 / unit * 60 / bpm * rate
        let every = max(1, Int((70 / (CGFloat(bar / end) * span)).rounded(.up)))
        context.setLineWidth(1)
        var index = 0
        while Double(index) * bar <= end, index < 10_000 {
            let position = x(Double(index) * bar)
            context.setStrokeColor(Drawing.color(255, 255, 255, index % every == 0 ? 0.10 : 0.04))
            context.strokeLineSegments(between: [CGPoint(x: position, y: header + 6), CGPoint(x: position, y: height - bottom)])
            if readable, index % every == 0 {
                Drawing.text(context, "\(index + 1)", at: CGPoint(x: position + 5, y: header + 6), size: 14, color: grey)
            }
            index += 1
        }

        for (row, track) in tracks.enumerated() {
            let y = lanes + lane * CGFloat(row)
            if row % 2 == 1 {
                context.setFillColor(Drawing.color(255, 255, 255, 0.025))
                context.fill(CGRect(x: 16, y: y, width: width - 32, height: lane))
            }
            let color = track.muted ? Drawing.color(0x5A, 0x5F, 0x66) : track.color
            Drawing.roundedRect(context, CGRect(x: 24, y: y + lane * 0.2, width: 6, height: lane * 0.6), radius: 3, fill: color)
            if readable, lane >= 24 {
                let size = min(26, lane * 0.4)
                Drawing.text(context, track.name, at: CGPoint(x: 42, y: y + (lane - size * 1.25) / 2),
                             size: size, bold: true, color: track.muted ? grey : white, width: left - 54)
            }
            for clip in track.clips {
                let box = CGRect(x: x(clip.start), y: y + 5, width: max(2, x(clip.start + clip.length) - x(clip.start)),
                                 height: lane - 10)
                draw(clip, in: box, on: context, color: clip.muted || track.muted ? Drawing.color(0x5A, 0x5F, 0x66) : color,
                     samples: clip.length, readable: readable)
            }
        }

        let amber = Drawing.color(0xF2, 0xC9, 0x4C)
        for (start, name) in markers {
            let position = x(start)
            context.setStrokeColor(Drawing.color(0xF2, 0xC9, 0x4C, 0.35))
            context.setLineDash(phase: 0, lengths: [4, 5])
            context.strokeLineSegments(between: [CGPoint(x: position, y: top), CGPoint(x: position, y: height - bottom)])
            context.setLineDash(phase: 0, lengths: [])
            Drawing.roundedRect(context, CGRect(x: position - 1, y: header + 24, width: 10, height: 10), radius: 2, fill: amber)
            if readable { Drawing.text(context, name, at: CGPoint(x: position + 13, y: header + 21), size: 13, color: amber, width: 160) }
        }
        if let playhead, playhead > 0, playhead < end {
            let position = x(playhead)
            context.setStrokeColor(Drawing.green)
            context.setLineWidth(2)
            context.strokeLineSegments(between: [CGPoint(x: position, y: header + 4), CGPoint(x: position, y: height - bottom)])
            context.setFillColor(Drawing.green)
            context.move(to: CGPoint(x: position - 8, y: header + 2))
            context.addLine(to: CGPoint(x: position + 8, y: header + 2))
            context.addLine(to: CGPoint(x: position, y: header + 14))
            context.fillPath()
        }
        guard let image = context.makeImage() else { throw ReadError.invalid }
        return image
    }

    private static func draw(_ clip: Clip, in box: CGRect, on context: CGContext, color: CGColor, samples: Double,
                             readable: Bool) {
        Drawing.roundedRect(context, box, radius: min(8, box.height / 4), fill: color.copy(alpha: 0.88) ?? color)
        context.saveGState()
        context.addPath(CGPath(roundedRect: box, cornerWidth: min(8, box.height / 4), cornerHeight: min(8, box.height / 4), transform: nil))
        context.clip()
        let shade = Drawing.color(0, 0, 0, 0.28)
        for (fade, leading) in [(clip.fadeIn, true), (clip.fadeOut, false)] where fade > 0 {
            let w = box.width * CGFloat(min(1, fade / samples))
            let edge = leading ? box.minX : box.maxX, inner = leading ? box.minX + w : box.maxX - w
            context.move(to: CGPoint(x: edge, y: box.minY))
            context.addLine(to: CGPoint(x: inner, y: box.minY))
            context.addLine(to: CGPoint(x: edge, y: box.maxY))
            context.closePath()
            context.setFillColor(shade)
            context.fillPath()
        }
        if let low = clip.notes.map(\.pitch).min(), let high = clip.notes.map(\.pitch).max() {
            let body = box.insetBy(dx: 0, dy: box.height * 0.18)
            let step = body.height / CGFloat(high - low + 1)
            context.setFillColor(Drawing.color(0, 0, 0, 0.45))
            for note in clip.notes {
                let rect = CGRect(x: box.minX + box.width * CGFloat(note.start / samples),
                                  y: body.maxY - step * CGFloat(note.pitch - low + 1),
                                  width: max(1.5, box.width * CGFloat(note.length / samples)), height: max(1.5, step * 0.8))
                context.fill(rect)
            }
        }
        context.restoreGState()
        if readable, box.width > 48, box.height >= 20, clip.notes.isEmpty {
            Drawing.text(context, clip.name, at: CGPoint(x: box.minX + 8, y: box.minY + 4), size: min(18, box.height * 0.3),
                         bold: true, color: Drawing.color(0x10, 0x12, 0x14, 0.85), width: box.width - 14)
        }
    }

    private static func track(from raw: [String: Any], samplesPerTick: Double, limit: Double) -> Track? {
        guard raw["hidden"] as? Bool != true else { return nil }
        let playlists = raw["playlists"] as? [[String: Any]] ?? []
        let active = raw["active_playlist"] as? Int ?? 0
        let clips = ((playlists.indices.contains(active) ? playlists[active]["clips"] : nil) as? [[String: Any]] ?? [])
            .prefix(4000).compactMap { c -> Clip? in
                guard let rawStart = number(c["start"]), let rawLength = number(c["length"]), rawStart >= 0, rawLength > 0
                else { return nil }
                let start = min(rawStart, limit), length = min(rawLength, limit)
                let midi = ((c["content"] as? [String: Any])?["Midi"] as? [String: Any])?["sequence"] as? [String: Any]
                let notes = ((midi?["notes"] as? [[String: Any]]) ?? []).prefix(8000).compactMap { n -> (Double, Double, Int)? in
                    guard let s = number(n["start"]), let l = number(n["length"]), let p = n["pitch"] as? Int,
                          s >= 0, l >= 0, s * samplesPerTick < length else { return nil }
                    // MIDI pitches run from 0 to 127.
                    return (s * samplesPerTick, min(l * samplesPerTick, length), max(0, min(127, p)))
                }
                return Clip(start: start, length: length, name: c["name"] as? String ?? "", muted: c["muted"] as? Bool == true,
                            fadeIn: max(0, number((c["fade_in"] as? [String: Any])?["len"]) ?? 0),
                            fadeOut: max(0, number((c["fade_out"] as? [String: Any])?["len"]) ?? 0), notes: notes)
            }
        let kind = raw["kind"] as? String ?? ""
        guard !clips.isEmpty || ["Audio", "Instrument", "Midi"].contains(kind) else { return nil }
        let rgb = (raw["color"] as? [Int] ?? []).map { max(0, min(255, $0)) }
        let color = rgb.count == 3 ? Drawing.color(rgb[0], rgb[1], rgb[2]) : Drawing.color(0x8C, 0x8C, 0x8C)
        let muted = (raw["mixer"] as? [String: Any])?["mute"] as? Bool == true || raw["inactive"] as? Bool == true
        return Track(name: raw["name"] as? String ?? "", color: color, muted: muted, clips: clips)
    }

    private static func number(_ value: Any?) -> Double? {
        guard let n = value as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID(), n.doubleValue.isFinite else { return nil }
        return n.doubleValue
    }
}
