import SwiftUI
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#endif

/// SwiftUI view for the Share Extension
struct ShareExtensionView: View {
    let extensionContext: NSExtensionContext?
    var openURL: ((URL) -> Void)?

    @State private var inputText = ""
    @State private var detectedType: DataType = .text
    @State private var previewImage: Image?
    @State private var isLoading = true
    @State private var copiedFeedback = false
    @State private var openAppFeedback = false

    private let renderer = QRCodeRenderer()
    private let configuration = QRCodeConfiguration.default

    /// Smart summary of the content (name for vCard, handle for social, etc.)
    private var contentSummary: String? {
        DataTypeDetector.summarize(inputText, for: detectedType)
    }

    var body: some View {
        #if os(macOS)
        mainContent
            .frame(width: 320, height: 460)
            .task { await extractSharedContent() }
        #else
        NavigationStack {
            mainContent
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
        .task { await extractSharedContent() }
        #endif
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 16) {
            #if os(macOS)
            // Simple title bar for macOS popover
            HStack {
                Text(String(localized: "share.title", defaultValue: "Radical QR"))
                    .font(.headline)
                Spacer()
                Button(String(localized: "action.done", defaultValue: "Done")) {
                    extensionContext?.completeRequest(returningItems: nil)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal)

            Divider()
            #endif

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

                // Smart content summary (or truncated raw text as fallback)
                Text(contentSummary ?? String(inputText.prefix(120)) + (inputText.count > 120 && contentSummary == nil ? "..." : ""))
                    .font(.subheadline)
                    .fontWeight(contentSummary != nil ? .medium : .regular)
                    .foregroundStyle(contentSummary != nil ? .primary : .secondary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal)

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
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

                    // Open in app button
                    #if os(macOS)
                    Button {
                        openInApp()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.up.forward.app")
                            Text(String(localized: "share.openInApp", defaultValue: "Open in Radical QR"))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    #else
                    // iOS: Share Extensions cannot open other apps directly.
                    // Copy source content to clipboard so user can paste in main app.
                    Button {
                        openInApp()
                    } label: {
                        HStack {
                            Image(systemName: openAppFeedback ? "checkmark.circle" : "doc.on.clipboard")
                            Text(openAppFeedback
                                 ? String(localized: "share.contentCopied", defaultValue: "Copied! Open Radical QR and paste")
                                 : String(localized: "share.useInApp", defaultValue: "Use in Radical QR"))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(openAppFeedback ? .green : nil)
                    .controlSize(.large)
                    .disabled(openAppFeedback)
                    #endif
                }
                .padding(.horizontal)
            } else {
                Spacer()
                Text(String(localized: "share.noContent", defaultValue: "No content to encode"))
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(.vertical)
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

                // Try calendar event (iCal/ICS)
                if attachment.hasItemConformingToTypeIdentifier(UTType.calendarEvent.identifier) {
                    if let data = try? await attachment.loadItem(
                        forTypeIdentifier: UTType.calendarEvent.identifier
                    ) as? Data,
                       let icsString = String(data: data, encoding: .utf8) {
                        inputText = icsString
                        break
                    }
                }

                // Try plain text (fallback — must be last since vCard/iCal
                // data can also match public.plain-text)
                if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let text = try? await attachment.loadItem(
                        forTypeIdentifier: UTType.plainText.identifier
                    ) as? String {
                        inputText = text
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

    // MARK: - Open in Main App

    private func openInApp() {
        #if os(macOS)
        // On macOS, pass the content via a dedicated pasteboard to avoid
        // URL-encoding issues with large/complex data (vCard, iCal) and
        // prevent SwiftUI from opening a second window.
        let pb = NSPasteboard(name: NSPasteboard.Name("com.radicalsolution.radicalqr.share"))
        pb.clearContents()
        pb.setString(inputText, forType: .string)

        // Simple URL without content — the main app reads from the pasteboard
        if let url = URL(string: "radicalqr://paste") {
            openURL?(url)
        }

        extensionContext?.completeRequest(returningItems: nil)
        #else
        // iOS: Share Extensions cannot open other apps. Copy the source
        // content to clipboard so the user can paste it in the main app.
        UIPasteboard.general.string = inputText
        withAnimation { openAppFeedback = true }

        // Auto-dismiss after giving the user time to read the feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.extensionContext?.completeRequest(returningItems: nil)
        }
        #endif
    }
}
