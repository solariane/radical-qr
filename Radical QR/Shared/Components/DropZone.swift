import SwiftUI
import UniformTypeIdentifiers

/// A reusable drop zone for accepting files and text
struct DropZone: View {
    @Binding var text: String
    var onFileDrop: ((URL) -> Void)?
    var placeholder: String

    @State private var isTargeted = false
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            // Drop area
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
                    Image(systemName: isTargeted ? "arrow.down.circle.fill" : "arrow.down.doc")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.8))
                        .symbolEffect(.bounce, value: isTargeted)

                    Text(isTargeted
                         ? String(localized: "dropZone.release", defaultValue: "Release to generate")
                         : String(localized: "dropZone.hint", defaultValue: "Drop file or text here"))
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.9))

                    Text(String(localized: "dropZone.supportedTypes", defaultValue: "URLs, text files, or any text"))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(height: 160)
            .onDrop(of: supportedTypes, isTargeted: $isTargeted) { providers in
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
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    #endif

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
        .animation(.easeInOut(duration: 0.2), value: isTargeted)
        .animation(.easeInOut(duration: 0.2), value: text.isEmpty)
    }

    // MARK: - Drop Handling

    private var supportedTypes: [UTType] {
        [.text, .plainText, .utf8PlainText, .url, .fileURL, .data]
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        // Try URL first
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    DispatchQueue.main.async {
                        if url.isFileURL {
                            // Handle file drop
                            if let content = DataTypeDetector.extractContent(from: url) {
                                self.text = content
                            } else {
                                // If we can't extract content, use the file path
                                self.text = url.absoluteString
                            }
                            onFileDrop?(url)
                        } else {
                            // Handle URL drop
                            self.text = url.absoluteString
                        }
                    }
                }
            }
            return true
        }

        // Try plain text
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            _ = provider.loadObject(ofClass: String.self) { string, _ in
                if let string = string {
                    DispatchQueue.main.async {
                        self.text = string
                    }
                }
            }
            return true
        }

        return false
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        GradientBackground()

        DropZone(
            text: .constant(""),
            placeholder: "Enter URL or text..."
        )
        .padding()
    }
}
