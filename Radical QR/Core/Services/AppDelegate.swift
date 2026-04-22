#if os(macOS)
import AppKit

/// Minimal macOS app delegate — registers the Services provider.
/// URL open events (radicalqr:// scheme) are handled by DeepLinkHandler
/// via SwiftUI's .onOpenURL modifier, which reuses the existing window
/// instead of creating a new one.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = ServicesProvider.shared

        // During development, force the Services system to re-scan so new
        // NSServices entries in Info.plist become available without needing
        // a log-out / log-in cycle. Harmless at runtime.
        NSUpdateDynamicServices()
    }
}
#endif
