import Foundation
import QuickLookThumbnailing

final class ThumbnailProvider: QLThumbnailProvider {
    override func provideThumbnail(for request: QLFileThumbnailRequest,
                                   _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        do {
            let maxSide = min(2048, max(1, Int(ceil(max(request.maximumSize.width,
                                                        request.maximumSize.height) * request.scale))))
            let image: CGImage
            if let embedded = try? DocumentImage.load(request.fileURL, maxSide: maxSide) {
                image = embedded
            } else if let rendered = RenderXPC.render(request.fileURL, maxSide: maxSide, provider: ThumbnailProvider.self) {
                image = rendered
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
