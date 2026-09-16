import Foundation

/// Reads Wi-Fi details written for people — "Wi-Fi : Livebox-A1B2 / Mot de passe :
/// xK9#mQ2!", the card on a café table — rather than the `WIFI:` string, which
/// `DataTypeDetector` already recognises.
///
/// It works from labels, in the app's ten languages. Without a label nothing
/// tells a network name from any other word, so none is guessed.
nonisolated enum WiFiDetector {
    private enum Field { case network, password, security }

    private static let labels: [(String, Field)] = {
        let network = [
            "wi-fi", "wifi", "wlan", "ssid", "network name", "network", "nom du réseau", "réseau",
            "netzwerkname", "netzwerk", "nombre de la red", "red", "nome della rete", "nome rete", "rete",
            "nome da rede", "rede", "ネットワーク名", "ネットワーク", "网络名称", "网络", "無線網路",
            "اسم الشبكة", "الشبكة", "नेटवर्क का नाम", "नेटवर्क"
        ]
        let password = [
            "password", "passwort", "passcode", "pass", "pwd", "mot de passe", "mdp", "clé wi-fi", "clé wifi",
            "clé wpa", "clé", "wpa key", "key", "kennwort", "schlüssel", "contraseña", "clave", "senha",
            "パスワード", "密码", "密碼", "كلمة المرور", "كلمة السر", "पासवर्ड"
        ]
        let security = [
            "security", "sécurité", "sicherheit", "verschlüsselung", "seguridad", "sicurezza", "segurança",
            "encryption", "chiffrement", "セキュリティ", "安全性", "الأمان", "सुरक्षा"
        ]
        let all = network.map { ($0, Field.network) } + password.map { ($0, Field.password) }
            + security.map { ($0, Field.security) }
        // Longest first, so "clé wifi" is read as a password label before "wifi" is.
        return all.sorted { $0.0.count > $1.0.count }
    }()

    /// A label, then `:`, `：` or `=`. Not preceded by a letter, so "Password"
    /// inside "MyPassword:" is not one.
    private static let labelPattern: NSRegularExpression? = {
        let alternatives = labels.map { NSRegularExpression.escapedPattern(for: $0.0) }.joined(separator: "|")
        return try? NSRegularExpression(
            pattern: "(?<!\\p{L})(\(alternatives))\\s*[:：=]\\s*",
            options: [.caseInsensitive]
        )
    }()

    static func detect(in input: String) -> ContentDetection? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 300, let labelPattern else { return nil }
        let nsText = text as NSString
        let matches = labelPattern.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else { return nil }

        var values: [Field: String] = [:]
        for (index, match) in matches.enumerated() {
            let label = nsText.substring(with: match.range(at: 1)).lowercased()
            guard let field = labels.first(where: { $0.0 == label })?.1, values[field] == nil else { continue }
            let end = index + 1 < matches.count ? matches[index + 1].range.location : nsText.length
            let raw = nsText.substring(with: NSRange(location: NSMaxRange(match.range), length: end - NSMaxRange(match.range)))
            let value = cleanValue(raw, beforeNextLabel: index + 1 < matches.count)
            if !value.isEmpty { values[field] = value }
        }

        guard let ssid = values[.network] else { return nil }
        let password = values[.password] ?? ""
        let draft = WiFiDraft(ssid: ssid, password: password, security: security(from: values[.security], password: password))
        // A network without a password may be open — or the password is elsewhere.
        return ContentDetection(draft: .wifi(draft), confidence: password.isEmpty ? .medium : .high)
    }

    /// The value runs to the end of its line, minus the separator written before
    /// the next label ("Livebox / Mot de passe", "CafeGuest, password").
    private static func cleanValue(_ raw: String, beforeNextLabel: Bool) -> String {
        let lines = raw.components(separatedBy: .newlines)
        var value = (lines.first ?? raw).trimmingCharacters(in: .whitespaces)
        // Only when the next label is on the same line: a password may end in "-".
        if beforeNextLabel, lines.count == 1,
           let separator = ["/", "|", "-", "–", "—", ",", ";", "·"].first(where: { value.hasSuffix(" " + $0) || value.hasSuffix($0) && $0 == "," }) {
            value = String(value.dropLast(separator.count)).trimmingCharacters(in: .whitespaces)
        }
        // Quotes people put around a password so its spaces show.
        if value.count >= 2, let first = value.first, let last = value.last,
           ("\"«“'".contains(first) && "\"»”'".contains(last)) {
            value = String(value.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        }
        return value
    }

    private static func security(from label: String?, password: String) -> WiFiDraft.Security? {
        guard let label = label?.uppercased() else { return nil }
        if label.contains("WEP") { return .wep }
        if label.contains("WPA") { return .wpa }
        if ["NONE", "OPEN", "AUCUNE", "OUVERT", "KEINE", "OFFEN", "NINGUNA", "ABIERTA", "NESSUNA", "APERTA",
            "NENHUMA", "ABERTA", "なし", "无", "بلا", "कोई नहीं"].contains(where: { label.contains($0) }) {
            return WiFiDraft.Security.none
        }
        return password.isEmpty ? nil : .wpa
    }
}
