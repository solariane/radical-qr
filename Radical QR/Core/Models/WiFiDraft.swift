import Foundation

/// A Wi-Fi network the user can still edit, and the `WIFI:` string it encodes —
/// the format the iOS camera and Android offer to join.
nonisolated struct WiFiDraft: Equatable, Sendable {
    enum Security: String, CaseIterable, Sendable {
        /// WPA, WPA2 and WPA3 share one value in the format.
        case wpa = "WPA"
        case wep = "WEP"
        case none = "nopass"
    }

    var ssid: String
    var password: String = ""
    var security: Security = .wpa
    var isHidden: Bool = false

    init(ssid: String, password: String = "", security: Security? = nil, isHidden: Bool = false) {
        self.ssid = ssid
        self.password = password
        self.security = security ?? (password.isEmpty ? .none : .wpa)
        self.isHidden = isHidden
    }

    // MARK: - Encoding

    var wifiString: String {
        var fields = ["T:\(security.rawValue)", "S:\(Self.escape(ssid))"]
        if security != .none, !password.isEmpty {
            fields.append("P:\(Self.escape(password))")
        }
        if isHidden {
            fields.append("H:true")
        }
        return "WIFI:" + fields.joined(separator: ";") + ";;"
    }

    // MARK: - Decoding

    /// Reads back a `WIFI:` string holding only what this editor writes;
    /// `nil` for anything else (an EAP identity, say), which editing would drop.
    init?(wifiString: String) {
        let text = wifiString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.uppercased().hasPrefix("WIFI:") else { return nil }

        var ssid: String?
        var password = ""
        var security: Security?
        var isHidden = false
        for field in Self.splitUnescaped(String(text.dropFirst(5))) where !field.isEmpty {
            guard let colon = field.firstIndex(of: ":") else { return nil }
            let value = Self.unescape(String(field[field.index(after: colon)...]))
            switch field[..<colon].uppercased() {
            case "S": ssid = value
            case "P": password = value
            case "T": security = Security.allCases.first { $0.rawValue.caseInsensitiveCompare(value) == .orderedSame }
                ?? (value.isEmpty ? Security.none : nil)
                if security == nil { return nil }
            case "H": isHidden = value.lowercased() == "true"
            default: return nil
            }
        }
        guard let ssid, !ssid.isEmpty else { return nil }
        self.init(ssid: ssid, password: password, security: security, isHidden: isHidden)
    }

    // MARK: - Escaping

    /// The format escapes `\ ; , : "` with a backslash.
    static func escape(_ text: String) -> String {
        var result = ""
        for character in text {
            if "\\;,:\"".contains(character) { result.append("\\") }
            result.append(character)
        }
        return result
    }

    static func unescape(_ text: String) -> String {
        var result = ""
        var iterator = text.makeIterator()
        while let character = iterator.next() {
            if character == "\\", let next = iterator.next() {
                result.append(next)
            } else {
                result.append(character)
            }
        }
        return result
    }

    /// Splits on `;` that are not escaped, keeping the escapes for `unescape`.
    private static func splitUnescaped(_ text: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var iterator = text.makeIterator()
        while let character = iterator.next() {
            if character == "\\", let next = iterator.next() {
                current.append(character)
                current.append(next)
            } else if character == ";" {
                fields.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        fields.append(current)
        return fields
    }
}
