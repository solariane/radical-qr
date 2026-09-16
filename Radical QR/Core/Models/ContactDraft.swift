import Foundation

/// A contact card the user can still edit, and the vCard 3.0 it encodes.
///
/// One value per field: a QR code is a card handed over, not an address book
/// export, and every extra line makes the code denser.
nonisolated struct ContactDraft: Equatable, Sendable {
    var name: String = ""
    var organization: String = ""
    var jobTitle: String = ""
    var phone: String = ""
    var email: String = ""
    var website: String = ""
    var address: String = ""

    init(
        name: String = "", organization: String = "", jobTitle: String = "",
        phone: String = "", email: String = "", website: String = "", address: String = ""
    ) {
        self.name = name
        self.organization = organization
        self.jobTitle = jobTitle
        self.phone = phone
        self.email = email
        self.website = website
        self.address = address
    }

    // MARK: - Encoding

    var vCard: String {
        var lines = ["BEGIN:VCARD", "VERSION:3.0"]
        let fullName = name.trimmed
        // N is required by 3.0. Family name last is right for most of the
        // app's languages; a name without spaces (山田太郎) stays whole.
        let words = fullName.split(separator: " ").map(String.init)
        let family = words.count > 1 ? (words.last ?? fullName) : fullName
        let given = words.count > 1 ? words.dropLast().joined(separator: " ") : ""
        lines.append("N:\(Self.escape(family));\(Self.escape(given));;;")
        lines.append("FN:\(Self.escape(fullName))")

        func add(_ property: String, _ value: String, escaped: Bool = true) {
            let value = value.trimmed
            guard !value.isEmpty else { return }
            lines.append("\(property):\(escaped ? Self.escape(value) : value)")
        }
        add("ORG", organization)
        add("TITLE", jobTitle)
        add("TEL", phone)
        add("EMAIL", email)
        add("URL", website, escaped: false)
        let street = address.trimmed
        if !street.isEmpty {
            // The whole address in the street component: readers display it as
            // written, where splitting it by guess would put the city in the wrong box.
            lines.append("ADR:;;\(Self.escape(street));;;;")
        }
        lines.append("END:VCARD")
        return lines.joined(separator: "\r\n")
    }

    var isEmpty: Bool {
        [name, organization, jobTitle, phone, email, website, address].allSatisfy { $0.trimmed.isEmpty }
    }

    // MARK: - Decoding

    private static let editableProperties: Set<String> = [
        "VERSION", "N", "FN", "ORG", "TITLE", "TEL", "EMAIL", "URL", "ADR"
    ]

    /// Reads back a vCard this editor could have written: known properties, each
    /// at most once. A card exported from Contacts, with its photo, several
    /// numbers and labels, returns `nil` rather than losing them on edit.
    init?(vCard: String) {
        let lines = vCard.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard lines.first?.uppercased() == "BEGIN:VCARD", lines.last?.uppercased() == "END:VCARD" else {
            return nil
        }

        var values: [String: String] = [:]
        for line in lines.dropFirst().dropLast() {
            guard let colon = line.firstIndex(of: ":") else { return nil }
            let name = line[..<colon].split(separator: ";").first.map { String($0).uppercased() } ?? ""
            guard Self.editableProperties.contains(name), values[name] == nil else { return nil }
            values[name] = String(line[line.index(after: colon)...])
        }

        var fullName = values["FN"].map(Self.unescape) ?? ""
        if fullName.isEmpty, let structured = values["N"] {
            let parts = Self.splitUnescaped(structured, on: ";").map(Self.unescape)
            fullName = [parts.count > 1 ? parts[1] : "", parts.first ?? ""]
                .filter { !$0.isEmpty }.joined(separator: " ")
        }
        let address = values["ADR"].map { adr in
            Self.splitUnescaped(adr, on: ";").map(Self.unescape).filter { !$0.isEmpty }.joined(separator: ", ")
        } ?? ""

        self.init(
            name: fullName,
            organization: values["ORG"].map { Self.unescape($0.replacingOccurrences(of: ";", with: ", ")) } ?? "",
            jobTitle: values["TITLE"].map(Self.unescape) ?? "",
            phone: values["TEL"] ?? "",
            email: values["EMAIL"] ?? "",
            website: values["URL"] ?? "",
            address: address
        )
        guard !isEmpty else { return nil }
    }

    // MARK: - Escaping (vCard 3.0 text values)

    static func escape(_ text: String) -> String {
        EventDraft.escape(text)
    }

    static func unescape(_ text: String) -> String {
        EventDraft.unescape(text)
    }

    private static func splitUnescaped(_ text: String, on separator: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var iterator = text.makeIterator()
        while let character = iterator.next() {
            if character == "\\", let next = iterator.next() {
                current.append(character)
                current.append(next)
            } else if character == separator {
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

private extension String {
    nonisolated var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
