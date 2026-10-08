import Cocoa
import Quartz
import UniformTypeIdentifiers
import MpalCore

// Stable Objective-C name so Info.plist can say NSExtensionPrincipalClass = PreviewProvider.
@objc(PreviewProvider)
final class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let html = try Mpal.html(fromArchive: Data(contentsOf: request.fileURL))
        return QLPreviewReply(dataOfContentType: .html, contentSize: CGSize(width: 640, height: 480)) { reply in
            reply.stringEncoding = .utf8
            return Data(html.utf8)
        }
    }
}
