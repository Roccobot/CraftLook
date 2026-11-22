import Foundation
import QuickLookThumbnailing

final class ThumbnailProvider: QLThumbnailProvider {
    /// The renderer service of this extension; it runs the same Helpers as the preview service,
    /// the one copy of the renderers in the app.
    private static let service = (Bundle(for: ThumbnailProvider.self).bundleIdentifier ?? "") + ".render"

    override func provideThumbnail(for request: QLFileThumbnailRequest,
                                   _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        do {
            let url = request.fileURL
            let maxSide = min(2048, max(1, Int(ceil(max(request.maximumSize.width,
                                                        request.maximumSize.height) * request.scale))))
            let image = try RenderXPC.picture(url, maxSide: maxSide, service: Self.service)
            let factor = min(request.maximumSize.width / CGFloat(image.width),
                             request.maximumSize.height / CGFloat(image.height))
            let size = CGSize(width: max(1, floor(CGFloat(image.width) * factor)),
                              height: max(1, floor(CGFloat(image.height) * factor)))
            handler(QLThumbnailReply(contextSize: size, drawing: { context in
                DocumentImage.fill(context, with: image)
                return true
            }), nil)
        } catch {
            handler(nil, error)
        }
    }
}
