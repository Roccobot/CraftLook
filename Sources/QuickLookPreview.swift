import Foundation
import UniformTypeIdentifiers
import ImageIO
import QuickLookUI

final class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let url = request.fileURL
        let image: CGImage
        switch url.pathExtension.lowercased() {
        case "figcraft", "designcraft":
            image = try RenderXPC.render(url, maxSide: 2048, provider: PreviewProvider.self) ?? DocumentImage.load(url)
        default:
            if let embedded = try? DocumentImage.load(url) {
                image = embedded
            } else if let rendered = RenderXPC.render(url, maxSide: 2048, provider: PreviewProvider.self) {
                image = rendered
            } else {
                throw ReadError.unavailable
            }
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
}
