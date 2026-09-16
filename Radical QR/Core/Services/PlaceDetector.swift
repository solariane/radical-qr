import Foundation

/// A street address on its own — "12 rue de Rivoli, 75001 Paris" — which a
/// Maps link serves better than the text.
///
/// It runs after the event and contact detectors: an address with a date is an
/// appointment, one with a phone number is a card.
nonisolated enum PlaceDetector {
    static func detect(in input: String) -> ContentDetection? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 200,
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.address.rawValue) else {
            return nil
        }
        let nsText = text as NSString
        guard let match = detector.matches(in: text, range: NSRange(location: 0, length: nsText.length))
                .max(by: { $0.range.length < $1.range.length }) else { return nil }

        let matched = nsText.substring(with: match.range)
        let address = matched.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")

        // How much of the text the address is: "12 rue de Rivoli, Paris" is a place,
        // "je t'attends devant le 12 rue de Rivoli" is a sentence that mentions one.
        let coverage = Double(nonSpaceCount(matched)) / Double(max(nonSpaceCount(text), 1))
        guard coverage >= 0.6 else { return nil }

        // A street alone ("10 rue de la Paix") exists in every town; a city or a
        // postcode with it is somewhere.
        let parts = match.addressComponents ?? [:]
        let isLocated = parts[.street] != nil && (parts[.city] != nil || parts[.zip] != nil)
        let confidence: ContentDetection.Confidence = isLocated && coverage >= 0.9 ? .high : .medium
        return ContentDetection(draft: .place(PlaceDraft(address: address)), confidence: confidence)
    }

    private static func nonSpaceCount(_ text: String) -> Int {
        text.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }.count
    }
}
