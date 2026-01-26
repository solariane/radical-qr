import SwiftUI
import UniformTypeIdentifiers

/// A unified input zone that adapts to platform:
/// - iOS: Text field + file browser button
/// - iPadOS/macOS: Text field + file browser button + drag & drop
struct InputZone: View {
    @Binding var text: String
    var onFileSelected: ((URL) -> Void)?
    var placeholder: String

    @State private var isTargeted = false
    @State private var showFilePicker = false
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            #if os(macOS)
            macOSInputArea
            #else
            iOSInputArea
            #endif
        }
        .animation(.easeInOut(duration: 0.2), value: isTargeted)
        .animation(.easeInOut(duration: 0.2), value: text.isEmpty)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.text, .plainText, .url, .data],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }

    // MARK: - iOS Input Area

    #if !os(macOS)
    private var iOSInputArea: some View {
        VStack(spacing: 12) {
            // Text input with integrated file picker button
            HStack(spacing: 0) {
                TextField(placeholder, text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(.leading, 16)
                    .padding(.vertical, 14)
                    .focused($isTextFieldFocused)
                    .lineLimit(1...3)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()

                // Action buttons
                HStack(spacing: 8) {
                    if !text.isEmpty {
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) {
                                text = ""
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .transition(.scale.combined(with: .opacity))
                    }

                    // File picker button
                    Button {
                        showFilePicker = true
                    } label: {
                        Image(systemName: "folder")
                            .font(.title3)
                            .foregroundStyle(.accentColor)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.trailing, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            )

            // Helper text
            if text.isEmpty {
                Text(String(localized: "input.hint", defaultValue: "Enter URL, text, or browse files"))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
    #endif

    // MARK: - macOS Input Area (with Drag & Drop)

    #if os(macOS)
    private var macOSInputArea: some View {
        VStack(spacing: 16) {
            // Drop zone area
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                    )
                    .foregroundStyle(isTargeted ? .white : .white.opacity(0.5))
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isTargeted ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
                    )

                VStack(spacing: 12) {
                    Image(systemName: isTargeted ? "arrow.down.circle.fill" : "doc.badge.plus")
                        .font(.system(size: 36))
                        .foregroundStyle(.white.opacity(0.8))
                        .symbolEffect(.bounce, value: isTargeted)

                    Text(isTargeted
                         ? String(localized: "dropZone.release", defaultValue: "Release to add")
                         : String(localized: "dropZone.hint.mac", defaultValue: "Drop file here"))
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.9))

                    Button {
                        showFilePicker = true
                    } label: {
                        Label(
                            String(localized: "dropZone.browse", defaultValue: "Browse Files"),
                            systemImage: "folder"
                        )
                        .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                }
            }
            .frame(height: 140)
            .onDrop(of: supportedDropTypes, isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
            }

            // Or divider
            HStack {
                Rectangle()
                    .fill(.white.opacity(0.3))
                    .frame(height: 1)

                Text(String(localized: "dropZone.or", defaultValue: "or"))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))

                Rectangle()
                    .fill(.white.opacity(0.3))
                    .frame(height: 1)
            }

            // Text input field
            HStack(spacing: 12) {
                TextField(placeholder, text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white)
                    )
                    .focused($isTextFieldFocused)
                    .lineLimit(1...3)

                if !text.isEmpty {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            text = ""
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }

    private var supportedDropTypes: [UTType] {
        [.fileURL, .url, .text, .plainText, .utf8PlainText]
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        // Try file URL first (most common for drag & drop)
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                guard error == nil else { return }

                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        handleFileURL(url)
                    }
                }
            }
            return true
        }

        // Try URL (web URLs dragged from browser)
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, error in
                guard error == nil else { return }

                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        self.text = url.absoluteString
                    }
                } else if let url = item as? URL {
                    DispatchQueue.main.async {
                        self.text = url.absoluteString
                    }
                }
            }
            return true
        }

        // Try plain text
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, error in
                guard error == nil else { return }

                if let data = item as? Data,
                   let string = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self.text = string
                    }
                } else if let string = item as? String {
                    DispatchQueue.main.async {
                        self.text = string
                    }
                }
            }
            return true
        }

        return false
    }

    private func handleFileURL(_ url: URL) {
        // Try to extract content from the file
        if let content = DataTypeDetector.extractContent(from: url) {
            self.text = content
        } else {
            // For files we can't read, just use the URL
            self.text = url.absoluteString
        }
        onFileSelected?(url)
    }
    #endif

    // MARK: - File Import Handler

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            // Request access to the file
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            if let content = DataTypeDetector.extractContent(from: url) {
                text = content
            } else {
                text = url.absoluteString
            }
            onFileSelected?(url)

        case .failure:
            // Handle error silently or show alert
            break
        }
    }
}

// MARK: - Preview

#Preview("iOS") {
    ZStack {
        GradientBackground()

        InputZone(
            text: .constant(""),
            placeholder: "Enter URL or text..."
        )
        .padding()
    }
}

#Preview("macOS") {
    ZStack {
        GradientBackground()

        InputZone(
            text: .constant(""),
            placeholder: "Enter URL or text..."
        )
        .padding()
        .frame(width: 400)
    }
}
