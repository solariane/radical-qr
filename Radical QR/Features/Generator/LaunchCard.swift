import SwiftUI
import UniformTypeIdentifiers
#if !os(macOS)
import PhotosUI
#endif

/// The screen you meet when the app opens with nothing to encode.
///
/// It used to be a field, two lines of help, and two thirds of empty gradient —
/// the app's first impression saying almost nothing. This gives the space a job:
/// one large target that states what the app takes, the field itself, and the
/// three ways content actually arrives: the clipboard, an existing code in a
/// picture, and a file.
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

    @Environment(\.scenePhase) private var scenePhase
    /// Bumped on every return to the foreground: `PasteButton` decides whether
    /// it is enabled when it is created, so copying in another app would leave
    /// it greyed out until something else forced a rebuild.
    @State private var pasteboardGeneration = 0

    @State private var showFilePicker = false
    @State private var showImagePicker = false
    #if !os(macOS)
    @State private var showScanner = false
    #endif
    @State private var isTargeted = false
    @State private var decodeFailed = false
    @FocusState private var isFieldFocused: Bool
    #if !os(macOS)
    @State private var pickedPhoto: PhotosPickerItem?
    #endif

    private let decoder = QRCodeDecoder()

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
            allowedContentTypes: [.text, .plainText, .url, .image, .data],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            open(url: url)
        }
        #if os(macOS)
        .fileImporter(
            isPresented: $showImagePicker,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            duplicate(fromImageAt: url)
        }
        #else
        .photosPicker(isPresented: $showImagePicker, selection: $pickedPhoto, matching: .images)
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            Task { await duplicate(from: item) }
        }
        #endif
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { pasteboardGeneration += 1 }
        }
        #if !os(macOS)
        .fullScreenCover(isPresented: $showScanner) {
            CodeScannerSheet(
                onFound: { payload in
                    showScanner = false
                    withAnimation(.easeOut(duration: 0.2)) { text = payload }
                },
                onCancel: { showScanner = false }
            )
        }
        #endif
        .alert(
            String(localized: "duplicate.notFound", defaultValue: "No QR code in that picture"),
            isPresented: $decodeFailed
        ) {
            Button(String(localized: "error.dismiss", defaultValue: "OK"), role: .cancel) {}
        } message: {
            Text(String(
                localized: "duplicate.notFound.detail",
                defaultValue: "Try a sharper picture, or one where the whole code is visible."
            ))
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
                    Text(String(localized: "launch.headline", defaultValue: "Drop or paste anything"))
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

    /// The three ways content actually reaches the app. All are capsules because
    /// the system `PasteButton` is one and will not be reshaped — matching it is
    /// cheaper than fighting it. Three of them do not fit one phone-width row, so
    /// the layout falls back to two. "Browse files" is the app's own existing
    /// wording, reused rather than invented a second time.
    private var entryRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                pasteEntry
                duplicateEntry
                browseEntry
            }
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    pasteEntry
                    duplicateEntry
                }
                browseEntry
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var browseEntry: some View {
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
        .tint(Color.accentColor)
    }

    /// Reads an existing code out of a picture so it can be restyled. The photo
    /// picker runs out of process, so this costs no photo-library permission —
    /// and there is no camera here on purpose: a live scanner would need one,
    /// for an app that generates codes rather than reading them.
    @ViewBuilder
    private var duplicateEntry: some View {
        #if os(macOS)
        Button { showImagePicker = true } label: { duplicateLabel }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(Color.accentColor)
        #else
        if CodeScannerView.isSupported {
            Menu {
                Button {
                    showScanner = true
                } label: {
                    Label(String(localized: "duplicate.camera", defaultValue: "Camera"), systemImage: "camera")
                }
                Button {
                    showImagePicker = true
                } label: {
                    Label(
                        String(localized: "duplicate.library", defaultValue: "Photo Library", comment: "Menu item opening the system photo library. Use the platform's own name for it."),
                        systemImage: "photo.on.rectangle"
                    )
                }
            } label: {
                duplicateLabel
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(Color.accentColor)
        } else {
            // Pre-A12, or camera restricted: one destination, so no menu.
            Button { showImagePicker = true } label: { duplicateLabel }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(Color.accentColor)
        }
        #endif
    }

    private var duplicateLabel: some View {
        Label(
            String(localized: "launch.duplicate", defaultValue: "Duplicate", comment: "Button label. Verb: read an existing QR code so the user can recreate it."),
            systemImage: "qrcode.viewfinder"
        )
        .lineLimit(1)
        .minimumScaleFactor(0.8)
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
                String(localized: "launch.paste", defaultValue: "Paste", comment: "Button label. Verb: paste the clipboard contents."),
                systemImage: "doc.on.clipboard"
            )
            .lineLimit(1)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
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
        .tint(Color.accentColor)
        .id(pasteboardGeneration)
        #endif
    }

    #if os(macOS)
    private func pasteFromClipboard() {
        guard let pasted = NSPasteboard.general.string(forType: .string),
              !pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        withAnimation(.easeOut(duration: 0.2)) { text = pasted }
    }
    #endif

    // MARK: - Opening what was chosen

    /// Browsing accepts images too: a picture of a code is duplicated rather
    /// than read as text, so one button does the right thing per file.
    private func open(url: URL) {
        let isImage = (try? url.resourceValues(forKeys: [.contentTypeKey]))?
            .contentType?
            .conforms(to: .image) ?? false

        guard isImage else {
            onFileSelected(url)
            return
        }
        duplicate(fromImageAt: url)
    }

    private func duplicate(fromImageAt url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url),
              let decoded = decoder.decode(imageData: data) else {
            decodeFailed = true
            return
        }
        withAnimation(.easeOut(duration: 0.2)) { text = decoded }
    }

    // MARK: - Duplicating from the photo library

    #if !os(macOS)
    private func duplicate(from item: PhotosPickerItem) async {
        defer { pickedPhoto = nil }

        let picked = try? await item.loadTransferable(type: PickedImage.self)

        guard let picked, let decoded = decoder.decode(imageData: picked.data) else {
            decodeFailed = true
            return
        }
        withAnimation(.easeOut(duration: 0.2)) { text = decoded }
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
