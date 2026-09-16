import Foundation

/// Detected data types for QR code content
nonisolated enum DataType: String, CaseIterable, Identifiable, Sendable {
    case url
    case email
    case phone
    case sms
    case wifi
    case vcard
    case icalendar
    case geo
    case text

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .url: String(localized: "dataType.url", defaultValue: "URL")
        case .email: String(localized: "dataType.email", defaultValue: "Email")
        case .phone: String(localized: "dataType.phone", defaultValue: "Phone")
        case .sms: String(localized: "dataType.sms", defaultValue: "SMS")
        case .wifi: String(localized: "dataType.wifi", defaultValue: "Wi-Fi")
        case .vcard: String(localized: "dataType.vcard", defaultValue: "Contact")
        case .icalendar: String(localized: "dataType.icalendar", defaultValue: "Event")
        case .geo: String(localized: "dataType.geo", defaultValue: "Location")
        case .text: String(localized: "dataType.text", defaultValue: "Text")
        }
    }

    var iconName: String {
        switch self {
        case .url: "link"
        case .email: "envelope"
        case .phone: "phone"
        case .sms: "message"
        case .wifi: "wifi"
        case .vcard: "person.crop.rectangle"
        case .icalendar: "calendar"
        case .geo: "location"
        case .text: "text.alignleft"
        }
    }

    /// Description of what this data type is typically used for
    var description: String {
        switch self {
        case .url:
            String(localized: "dataType.url.description", defaultValue: "Website link")
        case .email:
            String(localized: "dataType.email.description", defaultValue: "Email address")
        case .phone:
            String(localized: "dataType.phone.description", defaultValue: "Phone number")
        case .sms:
            String(localized: "dataType.sms.description", defaultValue: "SMS message")
        case .wifi:
            String(localized: "dataType.wifi.description", defaultValue: "Wi-Fi network credentials")
        case .vcard:
            String(localized: "dataType.vcard.description", defaultValue: "Contact information")
        case .icalendar:
            String(localized: "dataType.icalendar.description", defaultValue: "Calendar event")
        case .geo:
            String(localized: "dataType.geo.description", defaultValue: "Geographic coordinates")
        case .text:
            String(localized: "dataType.text.description", defaultValue: "Plain text")
        }
    }
}

// MARK: - QR Input

/// Represents the input data for QR code generation
nonisolated struct QRInput: Sendable, Hashable {
    let content: String
    let detectedType: DataType

    /// The optimized string to encode in the QR code
    var encodedContent: String {
        switch detectedType {
        case .email where !content.lowercased().hasPrefix("mailto:"):
            return "mailto:\(content)"
        case .phone where !content.lowercased().hasPrefix("tel:"):
            return "tel:\(content.replacingOccurrences(of: " ", with: ""))"
        case .url where !content.lowercased().hasPrefix("http://") && !content.lowercased().hasPrefix("https://"):
            return "https://\(content)"
        default:
            return content
        }
    }

    init(content: String, detectedType: DataType) {
        self.content = content
        self.detectedType = detectedType
    }

    init(content: String) {
        self.content = content
        self.detectedType = DataTypeDetector.detect(content)
    }
}
