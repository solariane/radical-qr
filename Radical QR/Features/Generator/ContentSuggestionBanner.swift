import SwiftUI

/// Offered under the code when the text reads as an event, a Wi-Fi network or
/// a contact, but not clearly enough to switch on our own. Accepting opens the
/// form; the cross never asks again for that text.
struct ContentSuggestionBanner: View {
    let draft: ContentDraft
    let onAccept: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.semibold))
                if !detail.isEmpty {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 6)
            Button(acceptLabel, action: onAccept)
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "suggestion.dismiss", defaultValue: "Keep as text",
                                       comment: "Accessibility label: decline turning the entered text into a calendar event, Wi-Fi network or contact card."))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.10)))
    }

    private var symbol: String {
        switch draft {
        case .event: "calendar.badge.plus"
        case .wifi: "wifi"
        case .contact: "person.crop.circle.badge.plus"
        }
    }

    private var title: String {
        switch draft {
        case .event:
            String(localized: "event.suggestion.title", defaultValue: "Looks like a date",
                   comment: "Hint under the QR code: the text the user entered contains a date or time and could become a calendar event.")
        case .wifi:
            String(localized: "wifi.suggestion.title", defaultValue: "Looks like Wi-Fi details",
                   comment: "Hint under the QR code: the text the user entered contains a Wi-Fi network name (and maybe its password) and could become a code that joins the network.")
        case .contact:
            String(localized: "contact.suggestion.title", defaultValue: "Looks like contact details",
                   comment: "Hint under the QR code: the text the user entered contains a person's phone number or email and could become a contact card.")
        }
    }

    private var detail: String {
        switch draft {
        case .event(let event):
            event.isAllDay
                ? event.start.formatted(date: .abbreviated, time: .omitted)
                : event.start.formatted(date: .abbreviated, time: .shortened)
        case .wifi(let wifi):
            wifi.ssid
        case .contact(let contact):
            [contact.name, contact.phone, contact.email].first { !$0.isEmpty } ?? ""
        }
    }

    private var acceptLabel: String {
        switch draft {
        case .event:
            String(localized: "event.suggestion.accept", defaultValue: "Make an event",
                   comment: "Button: turn the entered text into a calendar event (appointment) that the QR code adds to the calendar.")
        case .wifi:
            String(localized: "wifi.suggestion.accept", defaultValue: "Make a Wi-Fi code",
                   comment: "Button: turn the entered text into a QR code that joins the Wi-Fi network when scanned.")
        case .contact:
            String(localized: "contact.suggestion.accept", defaultValue: "Make a contact card",
                   comment: "Button: turn the entered text into a contact card (vCard) that the QR code adds to the address book.")
        }
    }
}

#Preview {
    VStack {
        ContentSuggestionBanner(
            draft: .event(EventDraft(start: .now, end: .now.addingTimeInterval(3600))),
            onAccept: {}, onDismiss: {}
        )
        ContentSuggestionBanner(draft: .wifi(WiFiDraft(ssid: "Livebox-A1B2")), onAccept: {}, onDismiss: {})
        ContentSuggestionBanner(
            draft: .contact(ContactDraft(name: "Marie Dupont", phone: "06 12 34 56 78")),
            onAccept: {}, onDismiss: {}
        )
    }
    .padding()
}
