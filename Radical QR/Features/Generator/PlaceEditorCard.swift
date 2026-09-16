import SwiftUI

/// Edits the address a Maps link points to. One field, and a line saying what
/// scanning does, since a Maps link looks like any other code.
struct PlaceEditorCard: View {
    let draft: PlaceDraft
    let onChange: (PlaceDraft) -> Void
    let onKeepAsText: (() -> Void)?
    let onClear: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        EditorCard(
            type: .geo,
            title: String(localized: "place.title", defaultValue: "Place",
                          comment: "Header of the form for an address that opens in Maps: a place someone goes to (Lieu, Ort), not a town square and not the verb."),
            onKeepAsText: onKeepAsText,
            onClear: onClear
        ) {
            TextField(
                String(localized: "place.address.placeholder", defaultValue: "Address",
                       comment: "Placeholder: the postal address a Maps link opens."),
                text: Binding(get: { draft.address }, set: { onChange(PlaceDraft(address: $0)) }),
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .lineLimit(1...3)
            .focused($isFocused)
            #if os(iOS)
            .textInputAutocapitalization(.words)
            #endif
            .editorFieldBackground()

            Label(
                String(localized: "place.hint", defaultValue: "Scanning opens this address in Maps.",
                       comment: "Note under the address field: what happens when someone scans the code. Maps is Apple's app (Plans, Karten, マップ)."),
                systemImage: "map"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .onAppear {
            if draft.address.isEmpty { isFocused = true }
        }
    }
}

#Preview {
    ZStack {
        GradientBackground()
        PlaceEditorCard(
            draft: PlaceDraft(address: "12 rue de Rivoli, 75001 Paris"),
            onChange: { _ in }, onKeepAsText: {}, onClear: {}
        )
        .padding()
    }
}
