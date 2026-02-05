import Foundation
import Observation

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

        default:
            return false
        }
    }

    /// Clears the pending content after it has been consumed
    func clearPendingContent() {
        pendingContent = nil
    }
}
