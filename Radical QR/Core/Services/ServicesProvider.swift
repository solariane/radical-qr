#if os(macOS)
import AppKit
import Foundation

/// Receives macOS Services invocations (right-click → Services → Generate QR Code).
/// Extracts the best-matching content from the pasteboard (URL, vCard, iCal,
/// plain text) and hands it off to the running app via NotificationCenter.
///
/// The Info.plist `NSServices` array declares which types we accept and the
/// name of the @objc method — any change here must match the plist.
final class ServicesProvider: NSObject {
    static let shared = ServicesProvider()

    /// Notification posted when a service invocation has extracted content.
    /// `userInfo["content"]` contains the string ready for the generator.
    static let contentReceived = Notification.Name("RadicalQRServiceContentReceived")

    /// Content stored for cold-launch scenarios where the notification fires
    /// before GeneratorView has mounted. The view checks this on `onAppear`.
    var pendingContent: String?

    // Declared here so we can reference them uniformly.
    private static let vcardType = NSPasteboard.PasteboardType("public.vcard")
    private static let icalType = NSPasteboard.PasteboardType("com.apple.ical.ics")

    /// File extensions whose content should be read from disk rather than
    /// treated as a URL when received via the Services pasteboard.
    private static let contentFileExtensions: Set<String> = [
        "vcf", "vcard", "ics", "ical", "txt", "text", "md"
    ]

    // MARK: - Service entry points
    //
    // NSServices in Info.plist routes invocations to these selectors. The
    // signature is fixed by the Services API.

    @objc func generateQR(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString>?
    ) {
        let content = extractBestContent(from: pasteboard)

        guard let content, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error?.pointee = "No content found in selection" as NSString
            return
        }

        deliver(content)
    }

    // MARK: - Pasteboard extraction

    /// Picks the most useful content from the pasteboard, in priority order:
    /// file URL (read content) → vCard data → iCal data → web URL → plain text.
    private func extractBestContent(from pasteboard: NSPasteboard) -> String? {
        // URL — but if it's a file:// URL pointing to a known content file
        // (vcf, ics, …), read the file content instead of returning the path.
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let url = urls.first {
            if url.isFileURL {
                // Try to read meaningful content from the file.
                if let content = DataTypeDetector.extractContent(from: url) {
                    return content
                }
                // Unknown binary file — fall through to other pasteboard types.
            } else {
                return url.absoluteString
            }
        }

        // vCard — comes as a UTF-8 data blob on the pasteboard
        if let data = pasteboard.data(forType: Self.vcardType),
           let vcard = String(data: data, encoding: .utf8) {
            return vcard
        }

        // iCal event — same encoding
        if let data = pasteboard.data(forType: Self.icalType),
           let ics = String(data: data, encoding: .utf8) {
            return ics
        }

        // Plain text fallback
        if let strings = pasteboard.readObjects(forClasses: [NSString.self], options: nil) as? [String],
           let string = strings.first {
            return string
        }

        return nil
    }

    private func deliver(_ content: String) {
        // Store for cold-launch: GeneratorView.onAppear will pick this up if
        // the notification fires before the view has subscribed.
        pendingContent = content

        // Ensure the app is a regular (Dock-visible) process — Services can
        // launch an app in an accessory/background mode where windows never
        // appear even after calling activate().
        NSApp.setActivationPolicy(.regular)

        // Bring the app to the front so the generator view is visible.
        DispatchQueue.main.async {
            self.activateApp()

            NotificationCenter.default.post(
                name: Self.contentReceived,
                object: nil,
                userInfo: ["content": content]
            )
        }

        // On cold launch the window may not exist yet when the first activate
        // fires. Retry several times with increasing delays to cover the
        // SwiftUI window creation timeline.
        for delay in [0.3, 0.7, 1.2] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.activateApp()
            }
        }
    }

    func activateApp() {
        NSApp.activate(ignoringOtherApps: true)

        // Ensure the key window is ordered front (covers the case where the
        // window exists but was never made visible).
        if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }
}
#endif
