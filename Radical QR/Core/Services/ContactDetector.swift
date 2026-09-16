import Foundation

/// Reads contact details written for people — an email signature, "John Smith,
/// (415) 555-0132, john@acme.com" — into a contact card.
///
/// `NSDataDetector` finds the phone number, email, website and address. What
/// remains is split into pieces, and the first piece shaped like a person's
/// name becomes the name; a piece after it on the same line is the job title,
/// one on another line the company.
nonisolated enum ContactDetector {
    private static let maxLength = 400
    private static let maxLines = 8

    static func detect(in input: String) -> ContentDetection? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= maxLength,
              text.components(separatedBy: .newlines).count <= maxLines,
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue
                | NSTextCheckingResult.CheckingType.link.rawValue
                | NSTextCheckingResult.CheckingType.address.rawValue) else { return nil }

        let nsText = text as NSString
        var draft = ContactDraft()
        var covered: [NSRange] = []
        for match in detector.matches(in: text, range: NSRange(location: 0, length: nsText.length)) {
            let matched = nsText.substring(with: match.range)
            switch match.resultType {
            case .phoneNumber where draft.phone.isEmpty:
                draft.phone = match.phoneNumber ?? matched
            case .link where match.url?.scheme?.lowercased() == "mailto" && draft.email.isEmpty:
                draft.email = String(match.url?.absoluteString.dropFirst("mailto:".count) ?? Substring(matched))
            case .link where ["http", "https"].contains(match.url?.scheme?.lowercased() ?? "") && draft.website.isEmpty:
                draft.website = matched.lowercased().hasPrefix("http") ? matched : "https://\(matched)"
            case .address where draft.address.isEmpty:
                draft.address = matched.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                    .joined(separator: ", ")
            default:
                continue
            }
            covered.append(match.range)
        }
        // A phone number or an email is what makes it a card; the rest is decoration.
        guard !draft.phone.isEmpty || !draft.email.isEmpty else { return nil }

        var pieces = Self.pieces(of: nsText, removing: covered)

        if let nameIndex = pieces.firstIndex(where: { isName($0.text) }) {
            let name = pieces.remove(at: nameIndex)
            draft.name = name.text
            if nameIndex < pieces.count, pieces[nameIndex].line == name.line, pieces[nameIndex].text.count <= 60 {
                draft.jobTitle = pieces.remove(at: nameIndex).text
            }
        }
        if let companyIndex = pieces.firstIndex(where: { $0.text.count <= 50 && !$0.text.contains(where: \.isNumber) }) {
            draft.organization = pieces.remove(at: companyIndex).text
        }

        // Words left over mean prose around a number, not a card.
        guard pieces.count <= 1 else { return nil }
        let channels = [draft.phone, draft.email, draft.website, draft.address].filter { !$0.isEmpty }.count
        let hasName = !draft.name.isEmpty
        if hasName && channels >= 2 && pieces.isEmpty {
            return ContentDetection(draft: .contact(draft), confidence: .high)
        }
        if (hasName && channels >= 1) || channels >= 2 {
            return ContentDetection(draft: .contact(draft), confidence: .medium)
        }
        return nil
    }

    // MARK: - Pieces

    private struct Piece {
        let text: String
        let line: Int
    }

    /// Separators people put between the parts of a signature line.
    private static let separatorPattern = try? NSRegularExpression(pattern: #"\s+[|/–—·•-]\s+|\s*[|•·]\s*|,\s+"#)

    /// Labels written before a value ("Tél. :", "Email:") — dropped, not names.
    private static let labelPattern = try? NSRegularExpression(
        pattern: #"^(?:t[ée]l(?:[ée]phone)?|phone|mobile?|portable|cell|fax|e-?mail|mail|courriel|web(?:site)?|site(?: web)?|www|adresse|address|telefon|handy|teléfono|móvil|correo|telefono|cellulare|celular|電話|メール|电话|邮箱|هاتف|फ़ोन)\.?\s*[:：]?\s*"#,
        options: [.caseInsensitive]
    )

    /// The text left once the detected values are cut out, in pieces, each
    /// remembering its line.
    private static func pieces(of text: NSString, removing covered: [NSRange]) -> [Piece] {
        var result: [Piece] = []
        var lineNumber = 0
        text.enumerateSubstrings(in: NSRange(location: 0, length: text.length), options: .byLines) { _, lineRange, _, _ in
            defer { lineNumber += 1 }
            var line = text.substring(with: lineRange) as NSString
            for range in covered.sorted(by: { $0.location > $1.location }) {
                let overlap = NSIntersectionRange(range, lineRange)
                guard overlap.length > 0 else { continue }
                let local = NSRange(location: overlap.location - lineRange.location, length: overlap.length)
                line = line.replacingCharacters(in: local, with: " | ") as NSString
            }
            for part in split(line as String) {
                // Punctuation first: "/ Email:" only reads as a label once the "/" is gone.
                var value = part.trimmingCharacters(in: edgePunctuation)
                if let labelPattern {
                    value = labelPattern.stringByReplacingMatches(
                        in: value, range: NSRange(location: 0, length: (value as NSString).length), withTemplate: ""
                    )
                }
                value = value.trimmingCharacters(in: edgePunctuation)
                if !value.isEmpty {
                    result.append(Piece(text: value, line: lineNumber))
                }
            }
        }
        return result
    }

    private static let edgePunctuation = CharacterSet.whitespaces.union(CharacterSet(charactersIn: ",;:|/–—-·•()"))

    private static func split(_ line: String) -> [String] {
        guard let separatorPattern else { return [line] }
        let nsLine = line as NSString
        var parts: [String] = []
        var start = 0
        for match in separatorPattern.matches(in: line, range: NSRange(location: 0, length: nsLine.length)) {
            parts.append(nsLine.substring(with: NSRange(location: start, length: match.range.location - start)))
            start = NSMaxRange(match.range)
        }
        parts.append(nsLine.substring(from: start))
        return parts
    }

    // MARK: - Names

    private static let particles: Set<String> = ["de", "du", "des", "la", "le", "van", "von", "der", "den", "da", "di", "dos", "das", "y", "e", "bin", "al"]

    /// Two to four capitalised words ("Marie Dupont", "Anne de la Tour"), or a short
    /// run in a script without capitals (山田太郎). No digits, no "@".
    static func isName(_ text: String) -> Bool {
        guard text.count <= 40, !text.contains("@"), !text.contains(where: \.isNumber) else { return false }
        let words = text.split(separator: " ")
        let hasCase = text.contains { $0.isUppercase || $0.isLowercase }
        guard hasCase else {
            // Scripts without capitals: a short run that is all letters.
            return (2...12).contains(text.count) && words.count <= 2
                && text.allSatisfy { $0.isLetter || $0 == " " || $0 == "・" }
        }
        guard (2...4).contains(words.count) else { return false }
        return words.allSatisfy { word in
            if particles.contains(word.lowercased()) { return true }
            guard let first = word.first, first.isUppercase else { return false }
            return word.allSatisfy { $0.isLetter || $0 == "-" || $0 == "'" || $0 == "’" || $0 == "." }
        }
    }
}
