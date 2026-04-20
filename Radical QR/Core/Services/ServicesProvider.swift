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

    // Declared here so we can reference them uniformly.
    private static let vcardType = NSPasteboard.PasteboardType("public.vcard")
    private static let icalType = NSPasteboard.PasteboardType("com.apple.ical.ics")

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
    /// URL → vCard → iCal → plain text.
    private func extractBestContent(from pasteboard: NSPasteboard) -> String? {
        // URL (most specific — gives us a clean string)
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let url = urls.first {
            return url.absoluteString
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
        // Bring the app to the front so the generator view is visible.
        NSApp.activate(ignoringOtherApps: true)

        // Post on the main queue — SwiftUI observers run on MainActor.
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Self.contentReceived,
                object: nil,
                userInfo: ["content": content]
            )
        }
    }
}
#endif
