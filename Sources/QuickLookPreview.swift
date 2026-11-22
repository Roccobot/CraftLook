import Foundation
import UniformTypeIdentifiers
import ImageIO
import QuickLookUI

final class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    /// The renderer service of this extension; it runs the same Helpers as the thumbnail service,
    /// the one copy of the renderers in the app.
    private static let service = (Bundle(for: PreviewProvider.self).bundleIdentifier ?? "") + ".render"

    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let image = try RenderXPC.picture(request.fileURL, maxSide: 2048, service: Self.service)
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
}
