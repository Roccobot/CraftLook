import Foundation
import UniformTypeIdentifiers
import ImageIO
import QuickLookUI
import QuickLookThumbnailing

final class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let url = request.fileURL
        let image: CGImage
        if RenderXPC.rendersFirst(url.pathExtension.lowercased(), maxSide: 2048) {
            image = try await rendered(url) ?? DocumentImage.load(url)
        } else if let embedded = try? DocumentImage.load(url) {
            image = embedded
        } else if let picture = await rendered(url) {
            image = picture
        } else {
            throw ReadError.unavailable
        }
        let size = CGSize(width: image.width, height: image.height)
        return QLPreviewReply(dataOfContentType: .png, contentSize: size) { _ in
            let bytes = NSMutableData()
            guard let out = CGImageDestinationCreateWithData(bytes, UTType.png.identifier as CFString, 1, nil)
            else { throw ReadError.unavailable }
            CGImageDestinationAddImage(out, image, nil)
            guard CGImageDestinationFinalize(out) else { throw ReadError.unavailable }
            return bytes as Data
        }
    }

    /// A 2048-pixel thumbnail from Quick Look: the thumbnail extension of this app draws it with its
    /// renderer service, the one copy of the renderers in the app.
    private func rendered(_ url: URL) async -> CGImage? {
        let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 2048, height: 2048), scale: 1,
                                                   representationTypes: .thumbnail)
        return try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).cgImage
    }
}
