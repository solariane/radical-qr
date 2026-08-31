import SwiftUI
import UniformTypeIdentifiers

/// The screen you meet when the app opens with nothing to encode.
///
/// It used to be a field, two lines of help, and two thirds of empty gradient —
/// the app's first impression saying almost nothing. This gives the space a job:
/// one large target that states what the app takes, the field itself, and the two
/// ways content actually arrives. There is no "scan a photo" entry, because the
/// app generates codes rather than reading them.
///
/// It is deliberately identical on both platforms. macOS used to answer the same
/// moment with a different, white-on-violet drop zone that turned invisible once
/// this card put a light surface behind it; dropping there is handled by the
/// window-wide target in `GeneratorView`, so the card can stay one design.
struct LaunchCard: View {
    @Binding var text: String
    var summaryOverride: InputSummary?
    let onFileSelected: (URL) -> Void
    let placeholder: String
    var textFieldAnchorID: AnyHashable?

    @State private var showFilePicker = false
    @State private var isTargeted = false
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            dropTarget
            field
            entryRow
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.16), radius: 18, y: 6)
        )
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.text, .plainText, .url, .data],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            onFileSelected(url)
        }
    }

    // MARK: - Drop target

    /// Tapping anywhere on it starts typing; on iOS, dropping on it fills the
    /// field. On macOS the window-wide drop target catches the drag instead.
    private var dropTarget: some View {
        Button {
            isFieldFocused = true
        } label: {
            VStack(spacing: 14) {
                // Pale violet rather than neutral grey: at this size the mark's
                // rings are thick enough that grey reads as a blob.
                AppMarkGlyph(color: isTargeted
                    ? Color.accentColor
                    : Color(red: 0.788, green: 0.761, blue: 0.902))
                    .frame(width: 72, height: 72)

                VStack(spacing: 5) {
                    Text(String(localized: "launch.headline", defaultValue: "Paste anything"))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(String(
                        localized: "launch.subhead",
                        defaultValue: "Link, text, contact, Wi-Fi network, event. The format is worked out on its own."
                    ))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 26)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        isTargeted ? Color.accentColor : Color.secondary.opacity(0.28),
                        style: StrokeStyle(lineWidth: 2, dash: [6, 5])
                    )
            )
        }
        .buttonStyle(.plain)
        #if !os(macOS)
        .onDrop(of: [.url, .text, .plainText, .fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
        }
        #endif
        .animation(.easeInOut(duration: 0.18), value: isTargeted)
    }

    private var field: some View {
        InputZone(
            text: $text,
            summaryOverride: summaryOverride,
            onFileSelected: onFileSelected,
            placeholder: placeholder,
            textFieldAnchorID: textFieldAnchorID,
            isEmbedded: true,
            showsDropZone: false,
            focusBinding: $isFieldFocused
        )
    }

    #if !os(macOS)
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        if provider.canLoadObject(ofClass: URL.self) {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in
                    if url.isFileURL {
                        onFileSelected(url)
                    } else {
                        text = url.absoluteString
                    }
                }
            }
            return true
        }

        if provider.canLoadObject(ofClass: String.self) {
            _ = provider.loadObject(ofClass: String.self) { dropped, _ in
                guard let dropped else { return }
                Task { @MainActor in text = dropped }
            }
            return true
        }

        return false
    }
    #endif

    // MARK: - Entry points

    /// The two ways content actually reaches the app. Both are capsules because
    /// the system `PasteButton` is one and will not be reshaped — matching it is
    /// cheaper than fighting it. "Browse files" is the app's own existing wording
    /// for this, reused rather than invented a second time.
    private var entryRow: some View {
        HStack(spacing: 12) {
            pasteEntry

            Button {
                showFilePicker = true
            } label: {
                Label(
                    String(localized: "dropZone.browse", defaultValue: "Browse Files"),
                    systemImage: "folder"
                )
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(Color.accentColor)
        }
        .frame(maxWidth: .infinity)
    }

    /// On iOS this is the system `PasteButton`, not a button of ours reading
    /// `UIPasteboard`: reading the clipboard ourselves raises the "would like to
    /// paste" prompt every time, which is a poor greeting for an app whose whole
    /// pitch is that it takes nothing. Tapping the system button *is* the
    /// consent, so nothing is read that was not handed over.
    @ViewBuilder
    private var pasteEntry: some View {
        #if os(macOS)
        Button {
            pasteFromClipboard()
        } label: {
            Label(
                String(localized: "launch.paste", defaultValue: "Paste"),
                systemImage: "doc.on.clipboard"
            )
            .lineLimit(1)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(Color.accentColor)
        #else
        PasteButton(payloadType: String.self) { strings in
            guard let pasted = strings.first(where: {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }) else { return }
            withAnimation(.easeOut(duration: 0.2)) { text = pasted }
        }
        .labelStyle(.titleAndIcon)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(Color.accentColor)
        #endif
    }

    #if os(macOS)
    private func pasteFromClipboard() {
        guard let pasted = NSPasteboard.general.string(forType: .string),
              !pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        withAnimation(.easeOut(duration: 0.2)) { text = pasted }
    }
    #endif
}

#Preview("Launch") {
    ZStack {
        GradientBackground()
        LaunchCard(
            text: .constant(""),
            summaryOverride: nil,
            onFileSelected: { _ in },
            placeholder: "Enter URL, text, or drop a file...",
            textFieldAnchorID: nil
        )
        .padding(16)
    }
}
