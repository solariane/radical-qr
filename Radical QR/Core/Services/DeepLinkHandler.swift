import Foundation
import Observation
#if os(macOS)
import AppKit
#endif

/// Handles deep links from Share Extension and other sources
/// URL format: radicalqr://create?content=<encoded_content>
@Observable
@MainActor
final class DeepLinkHandler {
    /// Content received from a deep link, ready to be used in the generator
    var pendingContent: String?

    /// Processes an incoming URL and extracts any content to create a QR code
    /// - Parameter url: The incoming URL
    /// - Returns: True if the URL was handled, false otherwise
    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard url.scheme == "radicalqr" else { return false }

        switch url.host {
        case "create":
            // Extract content from query parameters
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let queryItems = components.queryItems,
               let contentItem = queryItems.first(where: { $0.name == "content" }),
               let content = contentItem.value {
                pendingContent = content
                return true
            }
            return false

        #if os(macOS)
        case "paste":
            // macOS Share Extension passes content via a dedicated pasteboard
            // to avoid URL-encoding issues with large data (vCard, iCal)
            let pb = NSPasteboard(name: NSPasteboard.Name("com.radicalsolution.radicalqr.share"))
            if let content = pb.string(forType: .string), !content.isEmpty {
                pb.clearContents()
                pendingContent = content
                return true
            }
            return false
        #endif

        default:
            return false
        }
    }

    /// Clears the pending content after it has been consumed
    func clearPendingContent() {
        pendingContent = nil
    }
}
