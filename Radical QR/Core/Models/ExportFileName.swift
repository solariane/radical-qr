import Foundation

/// The word or two that tell one export from the next: the site of a link, the
/// network of a Wi-Fi code, the name on a card, the title of an event. Two
/// codes of the same kind then rarely share a file name, without the timestamp
/// that made the old names unreadable. Nothing here leaves the device: it is
/// only the name the save panel proposes, which the user can change.
nonisolated enum ExportFileName {
    /// Longest description kept, in characters, so the size stays visible.
    static let maxLength = 40

    /// "qrcode-wifi-mabox-512px": prefix, what the code holds, size.
    static func baseName(for input: QRInput?, width: Int) -> String {
        var parts = ["qrcode"]
        if let input, let words = describe(input) { parts.append(words) }
        parts.append("\(width)px")
        return parts.joined(separator: "-")
    }

    static func describe(_ input: QRInput) -> String? {
        let text = input.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let words: String? = switch input.detectedType {
        case .url: site(in: text)
        case .email: text.removingPrefix("mailto:").components(separatedBy: "?").first
        case .phone: text.removingPrefix("tel:")
        case .sms: text.removingPrefix("smsto:").removingPrefix("sms:")
            .components(separatedBy: CharacterSet(charactersIn: "?:")).first
        case .wifi: (WiFiDraft(wifiString: text)?.ssid ?? field("S:", in: text, until: ";")).map { "wifi-\($0)" }
        case .vcard: ContactDraft(vCard: text)?.name ?? field("FN:", in: text, until: "\n")
        case .icalendar: EventDraft(icalendar: text)?.title ?? field("SUMMARY:", in: text, until: "\n")
        case .geo: nil
        case .text: text.split(whereSeparator: \.isWhitespace).prefix(4).joined(separator: " ")
        }
        return words.flatMap(slug)
    }

    /// Lowercase, accents folded, anything a file name should not hold turned
    /// into single dashes. Letters of every script stay: a Japanese name is a
    /// name too. Dots stay for domains, never at either end.
    static func slug(_ words: String) -> String? {
        let folded = words.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased()
        var result = ""
        for scalar in folded.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) || scalar == "." {
                result.unicodeScalars.append(scalar)
            } else if !result.hasSuffix("-") {
                result.append("-")
            }
        }
        let trimmed = String(result.prefix(maxLength)).trimmingCharacters(in: CharacterSet(charactersIn: "-."))
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func site(in text: String) -> String? {
        let link = text.lowercased().hasPrefix("http") ? text : "https://\(text)"
        guard let host = URL(string: link)?.host(), !host.isEmpty else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    /// A raw field when the draft refuses content it could not write back.
    private static func field(_ key: String, in text: String, until end: Character) -> String? {
        guard let start = text.range(of: key) else { return nil }
        let value = text[start.upperBound...].prefix { $0 != end && $0 != "\r" }
        return value.isEmpty ? nil : String(value)
    }
}

// In this file rather than ExportFormat.swift, which the share extension also
// compiles without the drafts this one reads.
extension ExportConfiguration {
    /// "qrcode-me.com-512px": what the code holds and the size. No extension:
    /// the save panel adds the one the format calls for.
    func suggestedBaseName(for input: QRInput? = nil) -> String {
        ExportFileName.baseName(for: input, width: size.width)
    }

    func suggestedFilename(for input: QRInput? = nil) -> String {
        "\(suggestedBaseName(for: input)).\(format.fileExtension)"
    }
}

private extension String {
    nonisolated func removingPrefix(_ prefix: String) -> String {
        lowercased().hasPrefix(prefix) ? String(dropFirst(prefix.count)) : self
    }
}
