import Foundation

/// Service for automatically detecting the type of content for QR code optimization
enum DataTypeDetector {
    /// Detects the data type from the given input string
    /// - Parameter input: The raw input string
    /// - Returns: The detected DataType
    static func detect(_ input: String) -> DataType {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for explicit prefixes first
        if let prefixType = detectByPrefix(trimmed) {
            return prefixType
        }

        // Check for pattern matches
        if let patternType = detectByPattern(trimmed) {
            return patternType
        }

        return .text
    }

    // MARK: - Private Detection Methods

    private static func detectByPrefix(_ input: String) -> DataType? {
        let lowercased = input.lowercased()

        if lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://") {
            return .url
        }

        if lowercased.hasPrefix("mailto:") {
            return .email
        }

        if lowercased.hasPrefix("tel:") {
            return .phone
        }

        if lowercased.hasPrefix("sms:") || lowercased.hasPrefix("smsto:") {
            return .sms
        }

        if lowercased.hasPrefix("wifi:") {
            return .wifi
        }

        if lowercased.hasPrefix("begin:vcard") {
            return .vcard
        }

        if lowercased.hasPrefix("begin:vcalendar") || lowercased.hasPrefix("begin:vevent") {
            return .icalendar
        }

        if lowercased.hasPrefix("geo:") {
            return .geo
        }

        if lowercased.hasPrefix("www.") {
            return .url
        }

        return nil
    }

    private static func detectByPattern(_ input: String) -> DataType? {
        // URL pattern (without prefix)
        if isLikelyURL(input) {
            return .url
        }

        // Email pattern
        if isValidEmail(input) {
            return .email
        }

        // Phone pattern
        if isLikelyPhoneNumber(input) {
            return .phone
        }

        // Geographic coordinates
        if isLikelyCoordinates(input) {
            return .geo
        }

        return nil
    }

    // MARK: - Pattern Validators

    private static func isLikelyURL(_ input: String) -> Bool {
        // Check for domain-like patterns
        let domainPattern = #"^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.[a-zA-Z]{2,}(/.*)?$"#

        guard let regex = try? NSRegularExpression(pattern: domainPattern, options: .caseInsensitive) else {
            return false
        }

        let range = NSRange(input.startIndex..., in: input)
        return regex.firstMatch(in: input, options: [], range: range) != nil
    }

    private static func isValidEmail(_ input: String) -> Bool {
        // RFC 5322 simplified email pattern
        let emailPattern = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#

        guard let regex = try? NSRegularExpression(pattern: emailPattern, options: .caseInsensitive) else {
            return false
        }

        let range = NSRange(input.startIndex..., in: input)
        return regex.firstMatch(in: input, options: [], range: range) != nil
    }

    private static func isLikelyPhoneNumber(_ input: String) -> Bool {
        // Remove common phone formatting characters
        let digitsOnly = input.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()

        // Phone numbers typically have 7-15 digits
        guard (7...15).contains(digitsOnly.count) else {
            return false
        }

        // Check if the original input looks like a phone number (mostly digits with some formatting)
        let phonePattern = #"^[\+]?[(]?[0-9]{1,4}[)]?[-\s\./0-9]{6,14}$"#

        guard let regex = try? NSRegularExpression(pattern: phonePattern, options: []) else {
            return false
        }

        let range = NSRange(input.startIndex..., in: input)
        return regex.firstMatch(in: input, options: [], range: range) != nil
    }

    private static func isLikelyCoordinates(_ input: String) -> Bool {
        // Matches patterns like "40.7128, -74.0060" or "40.7128,-74.0060"
        let coordPattern = #"^-?[0-9]{1,3}\.?[0-9]*,\s*-?[0-9]{1,3}\.?[0-9]*$"#

        guard let regex = try? NSRegularExpression(pattern: coordPattern, options: []) else {
            return false
        }

        let range = NSRange(input.startIndex..., in: input)
        guard regex.firstMatch(in: input, options: [], range: range) != nil else {
            return false
        }

        // Validate that the values are in valid coordinate ranges
        let parts = input.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2,
              let lat = Double(parts[0]),
              let lon = Double(parts[1]) else {
            return false
        }

        return (-90...90).contains(lat) && (-180...180).contains(lon)
    }
}

// MARK: - Input Formatter

extension DataTypeDetector {
    /// Formats the input appropriately for the detected type
    /// - Parameters:
    ///   - input: The raw input string
    ///   - type: The detected or specified data type
    /// - Returns: The formatted string ready for QR encoding
    static func format(_ input: String, for type: DataType) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        switch type {
        case .url:
            if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
                return trimmed
            }
            return "https://\(trimmed)"

        case .email:
            if trimmed.lowercased().hasPrefix("mailto:") {
                return trimmed
            }
            return "mailto:\(trimmed)"

        case .phone:
            if trimmed.lowercased().hasPrefix("tel:") {
                return trimmed
            }
            // Clean up phone number formatting
            let cleaned = trimmed.replacingOccurrences(of: " ", with: "")
            return "tel:\(cleaned)"

        case .sms:
            if trimmed.lowercased().hasPrefix("sms:") || trimmed.lowercased().hasPrefix("smsto:") {
                return trimmed
            }
            let cleaned = trimmed.replacingOccurrences(of: " ", with: "")
            return "sms:\(cleaned)"

        case .geo:
            if trimmed.lowercased().hasPrefix("geo:") {
                return trimmed
            }
            let cleaned = trimmed.replacingOccurrences(of: " ", with: "")
            return "geo:\(cleaned)"

        case .wifi, .vcard, .icalendar, .text:
            return trimmed
        }
    }
}

// MARK: - Content Summary

extension DataTypeDetector {
    /// Returns a human-readable summary of the detected content
    /// - Parameters:
    ///   - input: The raw input string
    ///   - type: The detected data type
    /// - Returns: A short summary describing the content
    static func summarize(_ input: String, for type: DataType) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        switch type {
        case .url:
            // Check for enriched URL metadata (social profiles, deep links)
            if let metadata = URLMetadataExtractor.extract(from: trimmed) {
                if let handle = metadata.handle {
                    return "\(metadata.platform) \(handle)"
                }
                return "\(metadata.platform) — \(metadata.displayLabel)"
            }
            // Fallback: extract domain from URL
            if let url = URL(string: trimmed.lowercased().hasPrefix("http") ? trimmed : "https://\(trimmed)"),
               let host = url.host {
                let path = url.path
                if path.isEmpty || path == "/" {
                    return host
                }
                return "\(host)\(path.prefix(30))\(path.count > 30 ? "..." : "")"
            }
            return nil

        case .email:
            let email = trimmed.lowercased().hasPrefix("mailto:") ? String(trimmed.dropFirst(7)) : trimmed
            return email

        case .phone:
            let phone = trimmed.lowercased().hasPrefix("tel:") ? String(trimmed.dropFirst(4)) : trimmed
            return phone

        case .sms:
            if let numberEnd = trimmed.firstIndex(of: "?") {
                let number = trimmed.lowercased().hasPrefix("sms:") ? String(trimmed.dropFirst(4).prefix(upTo: numberEnd)) : String(trimmed.prefix(upTo: numberEnd))
                return String(localized: "summary.sms", defaultValue: "SMS to \(number)")
            }
            let number = trimmed.lowercased().hasPrefix("sms:") ? String(trimmed.dropFirst(4)) : trimmed
            return String(localized: "summary.sms", defaultValue: "SMS to \(number)")

        case .wifi:
            // Parse WIFI:T:WPA;S:NetworkName;P:password;;
            if let ssidMatch = trimmed.range(of: "S:([^;]+)", options: .regularExpression) {
                let ssid = String(trimmed[ssidMatch]).dropFirst(2)
                return String(localized: "summary.wifi", defaultValue: "Wi-Fi: \(ssid)")
            }
            return nil

        case .vcard:
            // Parse vCard for name, email, phone
            var name: String?
            var contactDetail: String?
            var hasMoreData = false

            // Try FN (formatted name) first
            if let fnMatch = trimmed.range(of: "FN:([^\r\n]+)", options: .regularExpression) {
                name = String(String(trimmed[fnMatch]).dropFirst(3)).trimmingCharacters(in: .whitespaces)
            }

            // Fall back to N (structured name)
            if name == nil || name?.isEmpty == true {
                if let nMatch = trimmed.range(of: "N:([^;]*);([^;]*)", options: .regularExpression) {
                    let parts = String(trimmed[nMatch]).dropFirst(2).split(separator: ";")
                    if parts.count >= 2 {
                        let parsedName = "\(parts[1]) \(parts[0])".trimmingCharacters(in: .whitespaces)
                        if !parsedName.isEmpty {
                            name = parsedName
                        }
                    }
                }
            }

            // Look for email
            if let emailMatch = trimmed.range(of: "EMAIL[^:]*:([^\r\n]+)", options: .regularExpression) {
                let emailLine = String(trimmed[emailMatch])
                if let colonIndex = emailLine.firstIndex(of: ":") {
                    contactDetail = String(emailLine[emailLine.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                }
            }

            // If no email, look for phone
            if contactDetail == nil {
                if let telMatch = trimmed.range(of: "TEL[^:]*:([^\r\n]+)", options: .regularExpression) {
                    let telLine = String(trimmed[telMatch])
                    if let colonIndex = telLine.firstIndex(of: ":") {
                        contactDetail = String(telLine[telLine.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                    }
                }
            }

            // Check for additional data (ORG, TITLE, ADR, URL, etc.)
            let additionalFields = ["ORG:", "TITLE:", "ADR:", "URL:", "NOTE:", "BDAY:"]
            for field in additionalFields {
                if trimmed.range(of: field, options: .caseInsensitive) != nil {
                    hasMoreData = true
                    break
                }
            }

            // Also check for multiple emails or phones
            let emailCount = trimmed.components(separatedBy: "EMAIL").count - 1
            let telCount = trimmed.components(separatedBy: "TEL").count - 1
            if emailCount > 1 || telCount > 1 {
                hasMoreData = true
            }

            // Build the summary
            if let name = name, !name.isEmpty {
                var summary = name
                if let detail = contactDetail {
                    summary += " • \(detail)"
                }
                if hasMoreData {
                    summary += " …"
                }
                return summary
            }
            return String(localized: "summary.vcard.generic", defaultValue: "Contact card")

        case .icalendar:
            // Parse iCalendar for event summary and start date.
            // Important: search only inside the VEVENT block — the full
            // VCALENDAR often contains VTIMEZONE sections with their own
            // DTSTART (timezone rule origin dates, e.g. 1981) that must
            // not be confused with the event's start date.
            var eventSummary: String?
            var startDate: String?

            // Extract the first VEVENT block to scope our search.
            let fullText: String
            if let veventStart = trimmed.range(of: "BEGIN:VEVENT"),
               let veventEnd = trimmed.range(of: "END:VEVENT") {
                fullText = String(trimmed[veventStart.lowerBound..<veventEnd.upperBound])
            } else {
                fullText = trimmed
            }

            // Parse line-by-line (more reliable than regex with literal
            // control characters in NSRegularExpression character classes).
            for line in fullText.components(separatedBy: .newlines) {
                let l = line.trimmingCharacters(in: .whitespaces)
                if l.hasPrefix("SUMMARY:") {
                    eventSummary = String(l.dropFirst(8)).trimmingCharacters(in: .whitespaces)
                } else if l.hasPrefix("DTSTART"), let colonIdx = l.firstIndex(of: ":") {
                    let dateValue = String(l[l.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
                    startDate = formatICalendarDate(dateValue)
                }
            }

            // Build the summary
            if let summary = eventSummary, !summary.isEmpty {
                if let date = startDate {
                    return "\(summary) • \(date)"
                }
                return summary
            } else if let date = startDate {
                return String(localized: "summary.event.dateOnly", defaultValue: "Event on \(date)")
            }
            return String(localized: "summary.event.generic", defaultValue: "Calendar event")

        case .geo:
            let coords = trimmed.lowercased().hasPrefix("geo:") ? String(trimmed.dropFirst(4)) : trimmed
            let parts = coords.split(separator: ",")
            if parts.count >= 2 {
                return String(localized: "summary.geo", defaultValue: "Location: \(parts[0]), \(parts[1])")
            }
            return nil

        case .text:
            // For plain text, show preview
            if trimmed.count <= 50 {
                return nil // Short enough to show raw
            }
            return "\(trimmed.prefix(47))..."
        }
    }
    /// Formats an iCalendar date string into a human-readable format
    /// Handles formats like: 20240115, 20240115T090000, 20240115T090000Z
    private static func formatICalendarDate(_ dateString: String) -> String? {
        // Remove any timezone suffix (Z or +/-offset)
        var cleanDate = dateString.replacingOccurrences(of: "Z", with: "")
        if let plusIndex = cleanDate.firstIndex(of: "+") {
            cleanDate = String(cleanDate[..<plusIndex])
        }
        if let minusIndex = cleanDate.lastIndex(of: "-"), cleanDate.distance(from: minusIndex, to: cleanDate.endIndex) <= 5 {
            cleanDate = String(cleanDate[..<minusIndex])
        }

        // Remove time component if present (after T)
        if let tIndex = cleanDate.firstIndex(of: "T") {
            cleanDate = String(cleanDate[..<tIndex])
        }

        // Parse YYYYMMDD format
        guard cleanDate.count == 8,
              let year = Int(cleanDate.prefix(4)),
              let month = Int(cleanDate.dropFirst(4).prefix(2)),
              let day = Int(cleanDate.dropFirst(6).prefix(2)) else {
            return nil
        }

        // Create date components and format
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day

        guard let date = Calendar.current.date(from: components) else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - File Type Detection

extension DataTypeDetector {
    /// Detects if the dropped file contains content that should be converted to QR
    /// - Parameter url: The file URL
    /// - Returns: The content string if readable, nil otherwise
    static func extractContent(from url: URL) -> String? {
        let ext = url.pathExtension.lowercased()

        // Handle webloc/URL files first
        if ext == "webloc" || ext == "url" {
            return extractURLFromWebloc(url)
        }

        // Known text file extensions
        let textExtensions = [
            "txt", "text", "md", "markdown", "json", "xml", "html", "htm",
            "css", "js", "ts", "swift", "py", "rb", "java", "c", "cpp", "h",
            "csv", "log", "ini", "cfg", "conf", "yaml", "yml", "toml",
            "sh", "bash", "zsh", "fish", "ps1", "bat", "cmd",
            "sql", "graphql", "proto", "vcf", "vcard", "ics"
        ]

        // Try by extension first
        if textExtensions.contains(ext) {
            return tryReadTextFile(url)
        }

        // Try by UTI
        if let uti = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier {
            let textUTIs = [
                "public.plain-text",
                "public.utf8-plain-text",
                "public.text",
                "public.source-code",
                "public.script",
                "public.shell-script",
                "public.xml",
                "public.json",
                "public.html"
            ]

            if textUTIs.contains(uti) || uti.hasPrefix("public.text") || uti.contains("text") {
                return tryReadTextFile(url)
            }
        }

        // Last resort: try to read as text if file is small enough (< 100KB)
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let fileSize = attributes[.size] as? Int,
           fileSize < 100_000 {
            return tryReadTextFile(url)
        }

        return nil
    }

    private static func tryReadTextFile(_ url: URL) -> String? {
        // Try UTF-8 first
        if let content = try? String(contentsOf: url, encoding: .utf8) {
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            // Return nil if empty or looks like binary
            if trimmed.isEmpty || containsBinaryCharacters(trimmed) {
                return nil
            }
            return trimmed
        }

        // Try other common encodings
        let encodings: [String.Encoding] = [.isoLatin1, .windowsCP1252, .macOSRoman]
        for encoding in encodings {
            if let content = try? String(contentsOf: url, encoding: encoding) {
                let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty && !containsBinaryCharacters(trimmed) {
                    return trimmed
                }
            }
        }

        return nil
    }

    private static func containsBinaryCharacters(_ string: String) -> Bool {
        // Check for null bytes or other control characters that indicate binary
        for char in string.unicodeScalars {
            if char.value == 0 { return true }
            // Allow common control chars like newline, tab, carriage return
            if char.value < 32 && char.value != 9 && char.value != 10 && char.value != 13 {
                return true
            }
        }
        return false
    }

    private static func extractURLFromWebloc(_ url: URL) -> String? {
        // Try plist format first (macOS .webloc)
        if let data = try? Data(contentsOf: url),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
           let urlString = plist["URL"] as? String {
            return urlString
        }

        // Try Windows .url format (INI-like)
        if let content = try? String(contentsOf: url, encoding: .utf8) {
            for line in content.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.lowercased().hasPrefix("url=") {
                    return String(trimmed.dropFirst(4))
                }
            }
        }

        return nil
    }
}
