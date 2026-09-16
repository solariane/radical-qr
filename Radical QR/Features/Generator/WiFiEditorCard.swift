import SwiftUI

/// Edits a Wi-Fi network: its name, its password — shown in clear, since the
/// point is to hand it over — and the security the password belongs to.
struct WiFiEditorCard: View {
    let draft: WiFiDraft
    let onChange: (WiFiDraft) -> Void
    let onKeepAsText: (() -> Void)?
    let onClear: () -> Void

    @FocusState private var focusedField: Field?

    private enum Field { case network, password }

    var body: some View {
        EditorCard(type: .wifi, onKeepAsText: onKeepAsText, onClear: onClear) {
            credentialField(
                String(localized: "wifi.network.placeholder", defaultValue: "Network name",
                       comment: "Placeholder: the name (SSID) of a Wi-Fi network, as in iOS Settings."),
                text: binding(\.ssid),
                field: .network
            )
            if draft.security != .none {
                credentialField(
                    String(localized: "wifi.password.placeholder", defaultValue: "Password",
                           comment: "Placeholder: the password of a Wi-Fi network."),
                    text: binding(\.password),
                    field: .password
                )
            }
            securityPicker
            Toggle(
                String(localized: "wifi.hidden", defaultValue: "Hidden network",
                       comment: "Switch: the Wi-Fi network does not broadcast its name, as in iOS Settings."),
                isOn: Binding(get: { draft.isHidden }, set: { hidden in edit { $0.isHidden = hidden } })
            )
            .font(.subheadline)
        }
        .onAppear {
            if draft.ssid.isEmpty {
                focusedField = .network
            } else if draft.security != .none && draft.password.isEmpty {
                focusedField = .password
            }
        }
    }

    private func credentialField(_ placeholder: String, text: Binding<String>, field: Field) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.body.weight(field == .network ? .medium : .regular))
            .focused($focusedField, equals: field)
            #if os(iOS)
            .textInputAutocapitalization(.never)
            #endif
            .autocorrectionDisabled()
            .editorFieldBackground()
    }

    private var securityPicker: some View {
        HStack {
            Text(String(localized: "wifi.security", defaultValue: "Security",
                        comment: "Label before the Wi-Fi security type picker (WPA, WEP, none), as in iOS Settings."))
                .font(.subheadline)
            Spacer(minLength: 12)
            Picker(
                String(localized: "wifi.security", defaultValue: "Security",
                       comment: "Label before the Wi-Fi security type picker (WPA, WEP, none), as in iOS Settings."),
                selection: Binding(get: { draft.security }, set: { security in edit { $0.security = security } })
            ) {
                // Protocol names, the same in every language.
                Text(verbatim: "WPA").tag(WiFiDraft.Security.wpa)
                Text(verbatim: "WEP").tag(WiFiDraft.Security.wep)
                Text(String(localized: "wifi.security.none", defaultValue: "None",
                            comment: "Wi-Fi security option: an open network with no password."))
                    .tag(WiFiDraft.Security.none)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
    }

    private func edit(_ change: (inout WiFiDraft) -> Void) {
        var copy = draft
        change(&copy)
        onChange(copy)
    }

    private func binding(_ keyPath: WritableKeyPath<WiFiDraft, String>) -> Binding<String> {
        Binding(get: { draft[keyPath: keyPath] }, set: { value in edit { $0[keyPath: keyPath] = value } })
    }
}

#Preview {
    ZStack {
        GradientBackground()
        WiFiEditorCard(
            draft: WiFiDraft(ssid: "Livebox-A1B2", password: "xK9#mQ2!"),
            onChange: { _ in }, onKeepAsText: {}, onClear: {}
        )
        .padding()
    }
}
