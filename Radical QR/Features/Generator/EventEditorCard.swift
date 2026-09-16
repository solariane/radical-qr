import SwiftUI

/// Edits the event a pasted date became: title first (that is what the text
/// almost never carries), then when, then where and the link, folded until asked.
struct EventEditorCard: View {
    let draft: EventDraft
    let onChange: (EventDraft) -> Void
    /// `nil` when there is no text to go back to (an event loaded from history).
    let onKeepAsText: (() -> Void)?
    let onClear: () -> Void

    @Environment(\.generatorMetrics) private var metrics
    @State private var showsLocation = false
    @State private var showsLink = false
    @FocusState private var focusedField: Field?

    private enum Field { case title, location, link }

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.rowGap) {
            header
            titleField
            dateRows
            extraFields
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: metrics.cardPadding, cornerRadius: 26)
        .onAppear {
            showsLocation = !draft.location.isEmpty
            showsLink = !draft.url.isEmpty
            if draft.title.isEmpty { focusedField = .title }
        }
    }

    // MARK: - Rows

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .foregroundStyle(Color.accentColor)
            Text(DataType.icalendar.displayName)
                .font(.headline)
            Spacer(minLength: 8)
            if let onKeepAsText {
                Button(String(localized: "event.keepAsText", defaultValue: "Keep as text",
                              comment: "Button: undo the automatic conversion of pasted text into a calendar event, and encode the original text instead."),
                       action: onKeepAsText)
                    .font(.subheadline)
                    .buttonStyle(.borderless)
            }
            Button(action: onClear) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "event.clear", defaultValue: "Clear",
                                       comment: "Accessibility label: erase the content being encoded and start over."))
        }
    }

    private var titleField: some View {
        TextField(
            String(localized: "event.title.placeholder", defaultValue: "Title",
                   comment: "Placeholder: the name of a calendar appointment, e.g. “Dinner with Marie”."),
            text: binding(\.title)
        )
        .textFieldStyle(.plain)
        .font(.body.weight(.medium))
        .focused($focusedField, equals: .title)
        .submitLabel(.done)
        .fieldBackground()
    }

    private var dateRows: some View {
        VStack(spacing: 6) {
            DatePicker(
                String(localized: "event.starts", defaultValue: "Starts",
                       comment: "Label before the start date and time of a calendar event."),
                selection: Binding(get: { draft.start }, set: { date in edit { $0.moveStart(to: date) } }),
                displayedComponents: components
            )
            DatePicker(
                String(localized: "event.ends", defaultValue: "Ends",
                       comment: "Label before the end date and time of a calendar event."),
                selection: Binding(get: { draft.end }, set: { date in edit { $0.setEnd(date) } }),
                in: draft.start...,
                displayedComponents: components
            )
            Toggle(
                String(localized: "event.allDay", defaultValue: "All-day",
                       comment: "Switch: the calendar event lasts the whole day, with no start or end time."),
                isOn: Binding(get: { draft.isAllDay }, set: { allDay in edit { $0.setAllDay(allDay) } })
            )
        }
        .datePickerStyle(.compact)
        .font(.subheadline)
    }

    @ViewBuilder
    private var extraFields: some View {
        if showsLocation {
            TextField(
                String(localized: "event.location.placeholder", defaultValue: "Location",
                       comment: "Placeholder: where a calendar event takes place — an address or a venue, as in Apple Calendar."),
                text: binding(\.location)
            )
            .textFieldStyle(.plain)
            .focused($focusedField, equals: .location)
            .fieldBackground()
        }
        if showsLink {
            TextField(
                String(localized: "event.url.placeholder", defaultValue: "URL",
                       comment: "Placeholder: a web address attached to a calendar event, such as a video-call link."),
                text: binding(\.url)
            )
            .textFieldStyle(.plain)
            .focused($focusedField, equals: .link)
            #if os(iOS)
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            #endif
            .fieldBackground()
        }
        if !showsLocation || !showsLink {
            HStack(spacing: 8) {
                if !showsLocation {
                    addButton(
                        String(localized: "event.addLocation", defaultValue: "Add location",
                               comment: "Button: reveal the field for the place of a calendar event."),
                        systemImage: "mappin.and.ellipse"
                    ) {
                        showsLocation = true
                        focusedField = .location
                    }
                }
                if !showsLink {
                    addButton(
                        String(localized: "event.addURL", defaultValue: "Add link",
                               comment: "Button: reveal the field for a web link (e.g. a video call) attached to a calendar event."),
                        systemImage: "link"
                    ) {
                        showsLink = true
                        focusedField = .link
                    }
                }
            }
        }
    }

    private func addButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.2), action) }) {
            Label(title, systemImage: systemImage)
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.secondary.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
    }

    // MARK: - Editing

    private var components: DatePickerComponents {
        draft.isAllDay ? [.date] : [.date, .hourAndMinute]
    }

    private func edit(_ change: (inout EventDraft) -> Void) {
        var copy = draft
        change(&copy)
        onChange(copy)
    }

    private func binding(_ keyPath: WritableKeyPath<EventDraft, String>) -> Binding<String> {
        Binding(get: { draft[keyPath: keyPath] }, set: { value in edit { $0[keyPath: keyPath] = value } })
    }
}

private extension View {
    func fieldBackground() -> some View {
        padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.secondary.opacity(0.11))
            )
    }
}

// MARK: - Suggestion

/// Offered under the code when a date was found but not clearly enough to
/// switch on our own. Tapping it opens the editor; the cross never asks again.
struct EventSuggestionBanner: View {
    let draft: EventDraft
    let onAccept: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar.badge.plus")
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(String(localized: "event.suggestion.title", defaultValue: "Looks like a date",
                            comment: "Hint under the QR code: the text the user entered contains a date or time and could become a calendar event."))
                    .font(.caption.weight(.semibold))
                Text(dateText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            Button(String(localized: "event.suggestion.accept", defaultValue: "Make an event",
                          comment: "Button: turn the entered text into a calendar event (appointment) that the QR code adds to the calendar."),
                   action: onAccept)
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "event.suggestion.dismiss", defaultValue: "Keep as text",
                                       comment: "Accessibility label: decline turning the entered text into a calendar event."))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.10)))
    }

    private var dateText: String {
        draft.isAllDay
            ? draft.start.formatted(date: .abbreviated, time: .omitted)
            : draft.start.formatted(date: .abbreviated, time: .shortened)
    }
}

// MARK: - Previews

#Preview("Editor") {
    ZStack {
        GradientBackground()
        EventEditorCard(
            draft: EventDraft(start: .now, end: .now.addingTimeInterval(3600)),
            onChange: { _ in },
            onKeepAsText: {},
            onClear: {}
        )
        .padding()
    }
}

#Preview("Suggestion") {
    EventSuggestionBanner(
        draft: EventDraft(start: .now, end: .now.addingTimeInterval(3600)),
        onAccept: {},
        onDismiss: {}
    )
    .padding()
}
