import SwiftUI

/// Edits a contact card: name, phone and email always shown, company, job
/// title, website and address folded until they hold something.
struct ContactEditorCard: View {
    let draft: ContactDraft
    let onChange: (ContactDraft) -> Void
    let onKeepAsText: (() -> Void)?
    let onClear: () -> Void

    @State private var unfolded: Set<Field> = []
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case name, phone, email, company, jobTitle, website, address }

    private static let foldable: [Field] = [.company, .jobTitle, .website, .address]

    var body: some View {
        EditorCard(type: .vcard, onKeepAsText: onKeepAsText, onClear: onClear) {
            field(.name)
            field(.phone)
            field(.email)
            ForEach(Self.foldable.filter { unfolded.contains($0) }, id: \.self) { field($0) }
            let folded = Self.foldable.filter { !unfolded.contains($0) }
            if !folded.isEmpty {
                AddFieldRow {
                    ForEach(folded, id: \.self) { item in
                        AddFieldButton(title: placeholder(item), accessibilityLabel: addTitle(item)) {
                            unfolded.insert(item)
                            focusedField = item
                        }
                    }
                }
            }
        }
        .onAppear {
            unfolded = Set(Self.foldable.filter { !draft[keyPath: keyPath($0)].isEmpty })
            if draft.name.isEmpty { focusedField = .name }
        }
    }

    // MARK: - Fields

    private func field(_ item: Field) -> some View {
        TextField(placeholder(item), text: binding(keyPath(item)))
            .textFieldStyle(.plain)
            .font(item == .name ? .body.weight(.medium) : .body)
            .focused($focusedField, equals: item)
            #if os(iOS)
            .keyboardType(keyboard(item))
            .textInputAutocapitalization(item == .email || item == .website ? .never : .words)
            #endif
            .autocorrectionDisabled(item != .jobTitle)
            .editorFieldBackground()
    }

    private func keyPath(_ item: Field) -> WritableKeyPath<ContactDraft, String> {
        switch item {
        case .name: \.name
        case .phone: \.phone
        case .email: \.email
        case .company: \.organization
        case .jobTitle: \.jobTitle
        case .website: \.website
        case .address: \.address
        }
    }

    #if os(iOS)
    private func keyboard(_ item: Field) -> UIKeyboardType {
        switch item {
        case .phone: .phonePad
        case .email: .emailAddress
        case .website: .URL
        default: .default
        }
    }
    #endif

    private func placeholder(_ item: Field) -> String {
        switch item {
        case .name:
            String(localized: "contact.name.placeholder", defaultValue: "Name",
                   comment: "Placeholder: a person's full name on a contact card, as in the Contacts app.")
        case .phone:
            String(localized: "contact.phone.placeholder", defaultValue: "Phone",
                   comment: "Placeholder: a phone number on a contact card.")
        case .email:
            String(localized: "contact.email.placeholder", defaultValue: "Email",
                   comment: "Placeholder: an email address on a contact card.")
        case .company:
            String(localized: "contact.company.placeholder", defaultValue: "Company",
                   comment: "Placeholder: the company or organisation a contact works for.")
        case .jobTitle:
            String(localized: "contact.jobTitle.placeholder", defaultValue: "Job title",
                   comment: "Placeholder: a contact's position in their company, e.g. “Art director”.")
        case .website:
            String(localized: "contact.website.placeholder", defaultValue: "Website",
                   comment: "Placeholder: the web address on a contact card.")
        case .address:
            String(localized: "contact.address.placeholder", defaultValue: "Address",
                   comment: "Placeholder: a postal address on a contact card.")
        }
    }

    private func addTitle(_ item: Field) -> String {
        switch item {
        case .company:
            String(localized: "contact.addCompany", defaultValue: "Add company",
                   comment: "Button: reveal the field for the company of a contact card.")
        case .jobTitle:
            String(localized: "contact.addJobTitle", defaultValue: "Add job title",
                   comment: "Button: reveal the field for the job title (position) of a contact card.")
        case .website:
            String(localized: "contact.addWebsite", defaultValue: "Add website",
                   comment: "Button: reveal the field for the website of a contact card.")
        case .address:
            String(localized: "contact.addAddress", defaultValue: "Add address",
                   comment: "Button: reveal the field for the postal address of a contact card.")
        default:
            ""
        }
    }

    // MARK: - Editing

    private func binding(_ keyPath: WritableKeyPath<ContactDraft, String>) -> Binding<String> {
        Binding(get: { draft[keyPath: keyPath] }, set: { value in
            var copy = draft
            copy[keyPath: keyPath] = value
            onChange(copy)
        })
    }
}

#Preview {
    ZStack {
        GradientBackground()
        ContactEditorCard(
            draft: ContactDraft(name: "Marie Dupont", phone: "06 12 34 56 78", email: "marie@example.com"),
            onChange: { _ in }, onKeepAsText: {}, onClear: {}
        )
        .padding()
    }
}
