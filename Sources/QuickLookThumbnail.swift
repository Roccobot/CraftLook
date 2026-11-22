import Foundation
import QuickLookThumbnailing

final class ThumbnailProvider: QLThumbnailProvider {
    /// The renderer service lives in this extension only; the preview extension asks for a large
    /// thumbnail, so the renderers are in the app once.
    private static let service = (Bundle(for: ThumbnailProvider.self).bundleIdentifier ?? "") + ".render"

    override func provideThumbnail(for request: QLFileThumbnailRequest,
                                   _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        do {
            let url = request.fileURL
            let maxSide = min(2048, max(1, Int(ceil(max(request.maximumSize.width,
                                                        request.maximumSize.height) * request.scale))))
            let rendered = { RenderXPC.render(url, maxSide: maxSide, service: Self.service) }
            let image: CGImage
            if RenderXPC.rendersFirst(url.pathExtension.lowercased(), maxSide: maxSide), let picture = rendered() {
                image = picture
            } else if let embedded = try? DocumentImage.load(url, maxSide: maxSide) {
                image = embedded
            } else if let picture = rendered() {
                image = picture
            } else {
                throw ReadError.unavailable
            }
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
