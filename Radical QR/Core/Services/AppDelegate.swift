#if os(macOS)
import AppKit

/// Minimal macOS app delegate — only purpose is to register the Services
/// provider so that NSServices entries in Info.plist can reach our app.
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
