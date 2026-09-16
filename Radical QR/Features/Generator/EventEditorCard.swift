import SwiftUI

/// Edits the event a pasted date became: title first (that is what the text
/// almost never carries), then when, then where and the link, folded until asked.
struct EventEditorCard: View {
    let draft: EventDraft
    let onChange: (EventDraft) -> Void
    /// `nil` when there is no text to go back to (an event loaded from history).
    let onKeepAsText: (() -> Void)?
    let onClear: () -> Void

    @State private var showsLocation = false
    @State private var showsLink = false
    @FocusState private var focusedField: Field?

    private enum Field { case title, location, link }

    var body: some View {
        EditorCard(type: .icalendar, onKeepAsText: onKeepAsText, onClear: onClear) {
            titleField
            dateRows
            extraFields
        }
        .onAppear {
            showsLocation = !draft.location.isEmpty
            showsLink = !draft.url.isEmpty
            if draft.title.isEmpty { focusedField = .title }
        }
    }

    // MARK: - Rows

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
        .editorFieldBackground()
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
            TextField(locationPlaceholder, text: binding(\.location))
            .textFieldStyle(.plain)
            .focused($focusedField, equals: .location)
            .editorFieldBackground()
        }
        if showsLink {
            TextField(urlPlaceholder, text: binding(\.url))
            .textFieldStyle(.plain)
            .focused($focusedField, equals: .link)
            #if os(iOS)
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            #endif
            .editorFieldBackground()
        }
        if !showsLocation || !showsLink {
            AddFieldRow {
                if !showsLocation {
                    AddFieldButton(
                        title: locationPlaceholder,
                        accessibilityLabel: String(localized: "event.addLocation", defaultValue: "Add location",
                                                   comment: "Button: reveal the field for the place of a calendar event.")
                    ) {
                        showsLocation = true
                        focusedField = .location
                    }
                }
                if !showsLink {
                    AddFieldButton(
                        title: urlPlaceholder,
                        accessibilityLabel: String(localized: "event.addURL", defaultValue: "Add link",
                                                   comment: "Button: reveal the field for a web link (e.g. a video call) attached to a calendar event.")
                    ) {
                        showsLink = true
                        focusedField = .link
                    }
                }
            }
        }
    }

    private var locationPlaceholder: String {
        String(localized: "event.location.placeholder", defaultValue: "Location",
               comment: "Placeholder: where a calendar event takes place — an address or a venue, as in Apple Calendar.")
    }

    private var urlPlaceholder: String {
        String(localized: "event.url.placeholder", defaultValue: "URL",
               comment: "Placeholder: a web address attached to a calendar event, such as a video-call link.")
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
