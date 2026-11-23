import AppKit
import Foundation
import UniformTypeIdentifiers
import ImageIO
import QuickLookUI

final class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    /// The renderer service of this extension; it runs the same Helpers as the thumbnail service,
    /// the one copy of the renderers in the app.
    private static let service = (Bundle(for: PreviewProvider.self).bundleIdentifier ?? "") + ".render"

    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let url = request.fileURL
        // The picture can take a renderer's whole time limit: it waits on a thread of its own, not on
        // one of the few threads Swift concurrency shares among every task.
        let image = try await withCheckedThrowingContinuation { (done: CheckedContinuation<CGImage, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                done.resume(with: Result { try RenderXPC.picture(url, maxSide: 2048, service: Self.service) })
            }
        }
        // contentSize is in points: a 2048-pixel picture is 1024 points wide on a Retina screen.
        let scale = max(1, NSScreen.main?.backingScaleFactor ?? 2)
        let size = CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
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
