import Foundation

/// Generates context-aware default captions for QR codes
enum CaptionGenerator {

    /// Generates a default caption based on the input content and detected type
    /// - Parameter input: The QR input with content and detected type
    /// - Returns: A suggested caption string, or nil if no meaningful caption can be generated
    static func defaultCaption(for input: QRInput) -> String? {
        let content = input.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return nil }

        switch input.detectedType {
        case .vcard:
            return extractVCardName(from: content)

        case .url:
            // Social profile handle takes priority
            if let metadata = URLMetadataExtractor.extract(from: content),
               let handle = metadata.handle {
                return handle
            }
            // Fall back to domain
            return extractDomain(from: content)

        case .email:
            return content.lowercased().hasPrefix("mailto:") ? String(content.dropFirst(7)) : content

        case .phone:
            return content.lowercased().hasPrefix("tel:") ? String(content.dropFirst(4)) : content

        case .wifi:
            if let range = content.range(of: "S:([^;]+)", options: .regularExpression) {
                return String(String(content[range]).dropFirst(2))
            }
            return nil

        case .sms:
            let number = content.lowercased().hasPrefix("sms:") ? String(content.dropFirst(4)) : content
            if let end = number.firstIndex(of: "?") {
                return String(number[..<end])
            }
            return number

        case .icalendar:
            if let range = content.range(of: "SUMMARY:([^\r\n]+)", options: .regularExpression) {
                return String(String(content[range]).dropFirst(8)).trimmingCharacters(in: .whitespaces)
            }
            return nil

        case .geo:
            return nil

        case .text:
            return content.count <= 40 ? content : "\(content.prefix(37))..."
        }
    }

    // MARK: - Private Helpers

    private static func extractVCardName(from content: String) -> String? {
        // Try FN (formatted name) first
        if let range = content.range(of: "FN:([^\r\n]+)", options: .regularExpression) {
            let name = String(String(content[range]).dropFirst(3)).trimmingCharacters(in: .whitespaces)
            if !name.isEmpty { return name }
        }
        // Fall back to N (structured name)
        if let range = content.range(of: "N:([^;]*);([^;]*)", options: .regularExpression) {
            let parts = String(content[range]).dropFirst(2).split(separator: ";")
            if parts.count >= 2 {
                let name = "\(parts[1]) \(parts[0])".trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { return name }
            }
        }
        return nil
    }

    private static func extractDomain(from urlString: String) -> String? {
        let normalized = urlString.lowercased().hasPrefix("http") ? urlString : "https://\(urlString)"
        return URL(string: normalized)?.host
    }
}
