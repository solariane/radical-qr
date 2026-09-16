import Foundation

/// Structured content the generator edits in a form instead of a text field:
/// the QR payload is always regenerated from it.
nonisolated enum ContentDraft: Equatable, Sendable {
    case event(EventDraft)
    case wifi(WiFiDraft)
    case contact(ContactDraft)

    /// What the QR code encodes.
    var encoded: String {
        switch self {
        case .event(let draft): draft.icalendar
        case .wifi(let draft): draft.wifiString
        case .contact(let draft): draft.vCard
        }
    }

    var dataType: DataType {
        switch self {
        case .event: .icalendar
        case .wifi: .wifi
        case .contact: .vcard
        }
    }

    /// Reads back structured content this app could have written, so an item
    /// from history, a file or a share reopens in its form. `nil` for anything
    /// richer than the form holds.
    init?(content: String, type: DataType) {
        switch type {
        case .icalendar:
            guard let draft = EventDraft(icalendar: content) else { return nil }
            self = .event(draft)
        case .wifi:
            guard let draft = WiFiDraft(wifiString: content) else { return nil }
            self = .wifi(draft)
        case .vcard:
            guard let draft = ContactDraft(vCard: content) else { return nil }
            self = .contact(draft)
        default:
            return nil
        }
    }
}

/// Free text that reads as structured content, and how sure we are of it.
nonisolated struct ContentDetection: Equatable, Sendable {
    enum Confidence: Int, Comparable, Sendable {
        /// Worth offering — the user decides.
        case medium
        /// Clear enough to switch to the form straight away.
        case high

        static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    let draft: ContentDraft
    let confidence: Confidence
}

/// Runs the detectors over free text and keeps the most confident reading.
nonisolated enum ContentDetector {
    /// - Parameter type: what `DataTypeDetector` already made of the input. Only
    ///   plain text is read for structure; a "phone number" may still be a date
    ///   ("16.09.2026"), but only when the date is the whole of it.
    static func detect(in text: String, type: DataType, now: Date = Date()) -> ContentDetection? {
        switch type {
        case .phone:
            return EventDetector.detect(in: text, requireFullCoverage: true, now: now)
                .map { ContentDetection(draft: .event($0.draft), confidence: $0.confidence) }
        case .text:
            break
        default:
            return nil
        }

        // Wi-Fi labels ("Mot de passe :") are specific enough to go first.
        if let wifi = WiFiDetector.detect(in: text) {
            return wifi
        }
        let event = EventDetector.detect(in: text, now: now)
            .map { ContentDetection(draft: .event($0.draft), confidence: $0.confidence) }
        let contact = ContactDetector.detect(in: text)
        // A signature with a date in it is still a card when only the card is sure.
        switch (event, contact) {
        case let (event?, contact?):
            return contact.confidence > event.confidence ? contact : event
        default:
            return event ?? contact
        }
    }
}
