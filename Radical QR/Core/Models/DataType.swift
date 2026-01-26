import Foundation

/// Detected data types for QR code content
enum DataType: String, CaseIterable, Identifiable, Sendable {
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

// MARK: - Wi-Fi Configuration

struct WiFiConfiguration: Sendable {
    let ssid: String
    let password: String
    let securityType: SecurityType
    let isHidden: Bool

    enum SecurityType: String, CaseIterable, Sendable {
        case wpa = "WPA"
        case wep = "WEP"
        case none = "nopass"

        var displayName: String {
            switch self {
            case .wpa: "WPA/WPA2/WPA3"
            case .wep: "WEP"
            case .none: String(localized: "wifi.security.none", defaultValue: "None")
            }
        }
    }

    /// Generates the Wi-Fi QR code string format
    var qrString: String {
        var components = ["WIFI:"]
        components.append("T:\(securityType.rawValue);")
        components.append("S:\(escapeWiFiString(ssid));")
        if securityType != .none {
            components.append("P:\(escapeWiFiString(password));")
        }
        if isHidden {
            components.append("H:true;")
        }
        components.append(";")
        return components.joined()
    }

    private func escapeWiFiString(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: ":", with: "\\:")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

// MARK: - Contact Configuration (vCard)

struct ContactConfiguration: Sendable {
    let firstName: String
    let lastName: String
    let organization: String?
    let title: String?
    let email: String?
    let phone: String?
    let address: String?
    let url: String?

    /// Generates vCard 3.0 format string
    var qrString: String {
        var lines = [
            "BEGIN:VCARD",
            "VERSION:3.0",
            "N:\(lastName);\(firstName);;;"
        ]

        if let org = organization {
            lines.append("ORG:\(org)")
        }
        if let title = title {
            lines.append("TITLE:\(title)")
        }
        if let email = email {
            lines.append("EMAIL:\(email)")
        }
        if let phone = phone {
            lines.append("TEL:\(phone)")
        }
        if let address = address {
            lines.append("ADR:;;\(address);;;;")
        }
        if let url = url {
            lines.append("URL:\(url)")
        }

        lines.append("END:VCARD")
        return lines.joined(separator: "\r\n")
    }
}

// MARK: - QR Input

/// Represents the input data for QR code generation
struct QRInput: Sendable, Hashable {
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
