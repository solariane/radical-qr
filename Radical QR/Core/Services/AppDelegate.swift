#if os(macOS)
import AppKit

/// Minimal macOS app delegate — registers the Services provider and handles
/// URL open events from the Share Extension (preventing SwiftUI from creating
/// a second window).
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = ServicesProvider.shared

        // During development, force the Services system to re-scan so new
        // NSServices entries in Info.plist become available without needing
        // a log-out / log-in cycle. Harmless at runtime.
        NSUpdateDynamicServices()
    }

    /// Intercepts URL open events so we can handle them ourselves and prevent
    /// SwiftUI's `WindowGroup` from creating a second window.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard url.scheme == "radicalqr" else { continue }

            let content: String?

            switch url.host {
            case "paste":
                // Share Extension passed content via a dedicated pasteboard
                let pb = NSPasteboard(name: NSPasteboard.Name("com.radicalsolution.radicalqr.share"))
                content = pb.string(forType: .string)
                pb.clearContents()

            case "create":
                // Standard deep link with content in query parameter
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let item = components.queryItems?.first(where: { $0.name == "content" }) {
                    content = item.value
                } else {
                    content = nil
                }

            default:
                content = nil
            }

            guard let content, !content.isEmpty else { continue }

            // Deliver via the same mechanism as macOS Services — the
            // GeneratorView already observes this notification.
            ServicesProvider.shared.pendingContent = content
            DispatchQueue.main.async {
                ServicesProvider.shared.activateApp()
                NotificationCenter.default.post(
                    name: ServicesProvider.contentReceived,
                    object: nil,
                    userInfo: ["content": content]
                )
            }
        }
    }
}
#endif
