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
                            .foregroundStyle(Color.accentColor)
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
                Text(String(localized: "input.hint.ios", defaultValue: "Type URL, text, email, phone..."))
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
            // Drop zone area using NSViewRepresentable for reliable D&D
            MacOSDropZoneView(
                isTargeted: $isTargeted,
                onFileDrop: { url in
                    handleFileURL(url)
                },
                onTextDrop: { droppedText in
                    self.text = droppedText
                },
                onBrowse: {
                    showFilePicker = true
                }
            )
            .frame(height: 140)

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

            // Hint text
            if text.isEmpty {
                Text(String(localized: "input.hint.mac", defaultValue: "Drop a text file to read its content, or type directly"))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private func handleFileURL(_ url: URL) {
        // Security-scoped resource access for sandboxed apps
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Try to extract content from the file
        if let content = DataTypeDetector.extractContent(from: url) {
            self.text = content
        } else {
            // For files we can't read, show the file path
            self.text = url.path
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
                text = url.path
            }
            onFileSelected?(url)

        case .failure:
            // Handle error silently or show alert
            break
        }
    }
}

// MARK: - macOS Drop Zone using NSView for reliable drag & drop

#if os(macOS)
import AppKit

struct MacOSDropZoneView: NSViewRepresentable {
    @Binding var isTargeted: Bool
    var onFileDrop: (URL) -> Void
    var onTextDrop: (String) -> Void
    var onBrowse: () -> Void

    func makeNSView(context: Context) -> DropZoneNSView {
        let view = DropZoneNSView()
        view.onFileDrop = onFileDrop
        view.onTextDrop = onTextDrop
        view.onTargetChanged = { targeted in
            Task { @MainActor in
                self.isTargeted = targeted
            }
        }
        view.onBrowse = onBrowse
        return view
    }

    func updateNSView(_ nsView: DropZoneNSView, context: Context) {
        nsView.updateTargeted(isTargeted)
    }
}

class DropZoneNSView: NSView {
    var onFileDrop: ((URL) -> Void)?
    var onTextDrop: ((String) -> Void)?
    var onTargetChanged: ((Bool) -> Void)?
    var onBrowse: (() -> Void)?

    private var isCurrentlyTargeted = false
    private let iconView = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private let browseButton = NSButton()
    private let stackView = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        // Register for drag types
        registerForDraggedTypes([
            .fileURL,
            .URL,
            .string,
            NSPasteboard.PasteboardType("public.file-url"),
            NSPasteboard.PasteboardType("public.url")
        ])

        wantsLayer = true
        layer?.cornerRadius = 16

        // Setup icon
        iconView.image = NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: nil)
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 36, weight: .regular)
        iconView.contentTintColor = NSColor.white.withAlphaComponent(0.8)

        // Setup label
        label.stringValue = String(localized: "dropZone.hint.mac", defaultValue: "Drop file here")
        label.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        label.textColor = NSColor.white.withAlphaComponent(0.9)
        label.alignment = .center

        // Setup browse button
        browseButton.title = String(localized: "dropZone.browse", defaultValue: "Browse Files")
        browseButton.bezelStyle = .rounded
        browseButton.target = self
        browseButton.action = #selector(browseClicked)

        // Setup stack
        stackView.orientation = .vertical
        stackView.alignment = .centerX
        stackView.spacing = 12
        stackView.addArrangedSubview(iconView)
        stackView.addArrangedSubview(label)
        stackView.addArrangedSubview(browseButton)

        addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        updateAppearance()
    }

    @objc private func browseClicked() {
        onBrowse?()
    }

    func updateTargeted(_ targeted: Bool) {
        isCurrentlyTargeted = targeted
        updateAppearance()
    }

    private func updateAppearance() {
        if isCurrentlyTargeted {
            layer?.backgroundColor = NSColor.white.withAlphaComponent(0.15).cgColor
            layer?.borderWidth = 2
            layer?.borderColor = NSColor.white.cgColor
            iconView.image = NSImage(systemSymbolName: "arrow.down.circle.fill", accessibilityDescription: nil)
            label.stringValue = String(localized: "dropZone.release", defaultValue: "Release to add")
        } else {
            layer?.backgroundColor = NSColor.white.withAlphaComponent(0.05).cgColor
            layer?.borderWidth = 2
            layer?.borderColor = NSColor.white.withAlphaComponent(0.5).cgColor
            iconView.image = NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: nil)
            label.stringValue = String(localized: "dropZone.hint.mac", defaultValue: "Drop file here")
        }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 140)
    }

    // MARK: - Drag & Drop

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onTargetChanged?(true)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onTargetChanged?(false)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        onTargetChanged?(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard

        // Try to get file URLs first
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           let url = urls.first {
            Task { @MainActor in
                self.onFileDrop?(url)
            }
            return true
        }

        // Try to get web URLs
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let url = urls.first {
            Task { @MainActor in
                self.onTextDrop?(url.absoluteString)
            }
            return true
        }

        // Try to get string
        if let strings = pasteboard.readObjects(forClasses: [NSString.self], options: nil) as? [String],
           let string = strings.first {
            Task { @MainActor in
                self.onTextDrop?(string)
            }
            return true
        }

        return false
    }
}
#endif

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
