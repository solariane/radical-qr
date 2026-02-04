import SwiftUI
import UniformTypeIdentifiers

/// SwiftUI view for the Share Extension
struct ShareExtensionView: View {
    let extensionContext: NSExtensionContext?

    @State private var inputText = ""
    @State private var detectedType: DataType = .text
    @State private var previewImage: Image?
    @State private var isLoading = true
    @State private var copiedFeedback = false

    private let renderer = QRCodeRenderer()
    private let configuration = QRCodeConfiguration.default

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if !inputText.isEmpty {
                    // Data type badge
                    dataTypeBadge

                    // QR Preview
                    if let image = previewImage {
                        image
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 220, maxHeight: 220)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(white: 0.95))
                            )
                    }

                    // Input preview
                    Text(String(inputText.prefix(120)) + (inputText.count > 120 ? "..." : ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    Spacer()

                    // Copy button
                    Button {
                        Task { await copyToClipboard() }
                    } label: {
                        HStack {
                            Image(systemName: copiedFeedback ? "checkmark" : "doc.on.doc")
                            Text(copiedFeedback
                                 ? String(localized: "share.copied", defaultValue: "Copied!")
                                 : String(localized: "share.copy", defaultValue: "Copy QR Code"))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(copiedFeedback ? .green : .accentColor)
                    .controlSize(.large)
                    .padding(.horizontal)
                } else {
                    Spacer()
                    Text(String(localized: "share.noContent", defaultValue: "No content to encode"))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .padding(.vertical)
            .navigationTitle(String(localized: "share.title", defaultValue: "Radical QR"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.done", defaultValue: "Done")) {
                        extensionContext?.completeRequest(returningItems: nil)
                    }
                }
            }
        }
        .task {
            await extractSharedContent()
        }
    }

    // MARK: - Data Type Badge

    private var dataTypeBadge: some View {
        HStack(spacing: 8) {
            let metadata = (detectedType == .url) ? URLMetadataExtractor.extract(from: inputText) : nil
            Image(systemName: metadata?.iconName ?? detectedType.iconName)
            Text(metadata?.platform ?? detectedType.displayName)
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal)
    }

    // MARK: - Content Extraction

    private func extractSharedContent() async {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            isLoading = false
            return
        }

        for item in items {
            guard let attachments = item.attachments else { continue }

            for attachment in attachments {
                // Try URL first
                if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    if let url = try? await attachment.loadItem(
                        forTypeIdentifier: UTType.url.identifier
                    ) as? URL {
                        inputText = url.absoluteString
                        break
                    }
                }

                // Try plain text
                if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let text = try? await attachment.loadItem(
                        forTypeIdentifier: UTType.plainText.identifier
                    ) as? String {
                        inputText = text
                        break
                    }
                }

                // Try vCard (contacts)
                if attachment.hasItemConformingToTypeIdentifier(UTType.vCard.identifier) {
                    if let data = try? await attachment.loadItem(
                        forTypeIdentifier: UTType.vCard.identifier
                    ) as? Data,
                       let vcardString = String(data: data, encoding: .utf8) {
                        inputText = vcardString
                        break
                    }
                }
            }

            if !inputText.isEmpty { break }
        }

        detectedType = DataTypeDetector.detect(inputText)
        await generatePreview()
        isLoading = false
    }

    // MARK: - QR Generation

    @MainActor
    private func generatePreview() {
        guard !inputText.isEmpty else { return }
        let input = QRInput(content: inputText)
        previewImage = renderer.preview(input: input, configuration: configuration, previewSize: 256)
    }

    @MainActor
    private func copyToClipboard() async {
        let input = QRInput(content: inputText)
        let exportService = ExportService()
        try? await exportService.copyToClipboard(input: input, configuration: configuration, size: 512)

        withAnimation { copiedFeedback = true }
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        withAnimation { copiedFeedback = false }
    }
}
