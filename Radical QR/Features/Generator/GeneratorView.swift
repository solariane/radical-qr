import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Main QR code generator view.
///
/// The code stays on screen at all times: once the content is recognized the
/// input collapses to a single line inside the preview card, so the keyboard has
/// nothing left to cover. Settings live in `CustomizationRail` — one family at a
/// time, every option drawn rather than named — and the save row is pinned below
/// the scroll area so it is always reachable.
struct GeneratorView: View {
    @StateObject private var viewModel = GeneratorViewModel()
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(DeepLinkHandler.self) private var deepLinkHandler
    @Environment(\.modelContext) private var modelContext

    @State private var copiedFeedback = false
    @State private var showHelpSheet = false
    @State private var selectedFormat: ExportFormat = .png
    @State private var selectedSize: ExportSize = .medium
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var exportedFileURL: URL?
    @State private var family: CustomizationRail.Family = .shape
    @State private var paywallFeature: ProFeature?
    /// The input zone is folded away as soon as the content parses; this reopens it.
    @State private var isEditingInput = false
    @State private var isGlobalDropTargeted = false

    private let inputAnchorID = "input-section"

    private var showsInputZone: Bool {
        !viewModel.hasValidInput || isEditingInput
    }

    var body: some View {
        ZStack {
            GradientBackground()

            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 11) {
                            headerSection

                            if showsInputZone {
                                inputSection
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }

                            if viewModel.hasValidInput {
                                previewCard

                                CustomizationRail(
                                    configuration: $viewModel.configuration,
                                    family: $family,
                                    exportSize: $selectedSize,
                                    exportFormat: $selectedFormat,
                                    autoCaption: autoCaption,
                                    onLocked: { paywallFeature = $0 }
                                )
                            } else if purchaseManager.isPro {
                                RecentHistoryStrip { item in
                                    viewModel.loadFromHistory(item)
                                }
                            } else {
                                privacyNote
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 10)
                    }
                    .onChange(of: viewModel.hasValidInput) { _, hasInput in
                        guard hasInput else { return }
                        withAnimation(.easeInOut(duration: 0.25)) { isEditingInput = false }
                        scrollInputToTop(proxy: proxy)
                    }
                    .onChange(of: viewModel.inputText) { oldValue, newValue in
                        // Scroll when content arrives from outside (drag & drop,
                        // Services, Share) — not on every keystroke.
                        guard !newValue.isEmpty else { return }
                        let isExternalInput = oldValue.isEmpty || abs(newValue.count - oldValue.count) > 5
                        if isExternalInput {
                            scrollInputToTop(proxy: proxy)
                        }
                    }
                }
                #if os(iOS)
                .scrollDismissesKeyboard(.interactively)
                #endif

                if viewModel.hasValidInput {
                    actionRow
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 10)
                }
            }
        }
        #if os(macOS)
        .background(
            GlobalDropTargetView(
                isTargeted: $isGlobalDropTargeted,
                onFileDrop: { url in
                    if let content = DataTypeDetector.extractContent(from: url) {
                        viewModel.inputText = content
                    } else {
                        viewModel.inputText = url.absoluteString
                    }
                },
                onTextDrop: { text in
                    viewModel.inputText = text
                }
            )
        )
        .overlay {
            if isGlobalDropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.white, lineWidth: 3)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white.opacity(0.08))
                    )
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.2), value: isGlobalDropTargeted)
            }
        }
        #endif
        #if os(iOS)
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet) {
            if let url = exportedFileURL {
                ShareSheet(items: [url])
            }
        }
        #endif
        .sheet(isPresented: $showHelpSheet) {
            FormatHelpView()
        }
        .sheet(item: $paywallFeature) { feature in
            PaywallView(feature: feature)
        }
        .alert(item: $viewModel.error) { error in
            Alert(
                title: Text(String(localized: "error.title", defaultValue: "Error")),
                message: Text(error.localizedDescription),
                dismissButton: .default(Text(String(localized: "error.dismiss", defaultValue: "OK")))
            )
        }
        .onChange(of: deepLinkHandler.pendingContent) { _, newContent in
            guard let content = newContent else { return }
            Task { @MainActor in
                viewModel.inputText = content
                deepLinkHandler.clearPendingContent()
            }
        }
        .onAppear {
            // Handle any pending content on appear (for cold launch)
            if let content = deepLinkHandler.pendingContent {
                Task { @MainActor in
                    viewModel.inputText = content
                    deepLinkHandler.clearPendingContent()
                }
                return
            }
            #if os(macOS)
            // Cold-launch via macOS Service: the notification may have fired
            // before this view existed, so check the stored pending content.
            if let content = ServicesProvider.shared.pendingContent {
                Task { @MainActor in
                    viewModel.inputText = content
                    ServicesProvider.shared.pendingContent = nil
                }
            }
            #endif
        }
        #if os(macOS)
        .onReceive(NotificationCenter.default.publisher(for: ServicesProvider.contentReceived)) { note in
            guard let content = note.userInfo?["content"] as? String else { return }
            Task { @MainActor in
                viewModel.inputText = content
                ServicesProvider.shared.pendingContent = nil
            }
        }
        #endif
    }

    // MARK: - Scroll Helpers

    private func scrollInputToTop(proxy: ScrollViewProxy) {
        // Dispatch to next runloop so SwiftUI finishes laying out the newly
        // inserted preview/customization before we scroll.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            withAnimation(.easeInOut(duration: 0.35)) {
                proxy.scrollTo(inputAnchorID, anchor: .top)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 9) {
            AppMarkGlyph(color: .white)
                .frame(width: 22, height: 22)

            Text(verbatim: "Radical QR")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            Spacer()

            Button {
                showHelpSheet = true
            } label: {
                Image(systemName: "questionmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(.white.opacity(0.18)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "generator.help", defaultValue: "Formats and tips"))
        }
        .frame(height: 30)
        .id(inputAnchorID)
    }

    // MARK: - Input

    private var inputSection: some View {
        InputZone(
            text: $viewModel.inputText,
            summaryOverride: viewModel.inputSummaryOverride,
            onFileSelected: { url in
                viewModel.handleFileDrop(url)
            },
            placeholder: String(localized: "generator.input.placeholder", defaultValue: "Enter URL, text, or drop a file..."),
            textFieldAnchorID: AnyHashable(inputAnchorID)
        )
    }

    private var privacyNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield")
                .font(.footnote)
            Text(String(localized: "generator.subtitle", defaultValue: "No tracking. No storage. Just ephemeral QR codes."))
                .font(.footnote)
        }
        .foregroundStyle(.white.opacity(0.78))
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    // MARK: - Preview Card

    private var previewCard: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white)
                    .overlay {
                        if viewModel.configuration.backgroundType != .white {
                            QRPreviewBackground()
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }

                if let image = viewModel.previewImage {
                    image
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .padding(6)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else if viewModel.isGenerating {
                    ProgressView()
                }
            }
            // aspectRatio first, then the cap: framing first would let the square
            // grow to the whole proposed height and shove the rail off screen.
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 186, maxHeight: 186)
            .animation(.easeInOut(duration: 0.3), value: viewModel.previewImage != nil)

            scannabilityWarning
                .animation(.easeInOut(duration: 0.25), value: viewModel.scannability)

            contentPill
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: 14, cornerRadius: 26)
    }

    /// Only speaks up when the code is at risk. A permanent "scans fine" badge
    /// costs a line of chrome to say nothing.
    @ViewBuilder
    private var scannabilityWarning: some View {
        if viewModel.previewImage != nil, viewModel.scannability.level == .risky {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 1) {
                    Text(String(localized: "scan.risky", defaultValue: "May be hard to scan"))
                        .font(.caption.weight(.semibold))
                    if let reason = viewModel.scannability.reason {
                        Text(reason)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 6)
                if let fix = viewModel.scannability.fix {
                    Button(fix.label) {
                        withAnimation { viewModel.applyScanFix(fix) }
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.orange)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.12)))
        }
    }

    /// The folded input: what the code encodes, in one line, and the way back to
    /// editing it.
    private var contentPill: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) { isEditingInput.toggle() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: viewModel.urlMetadata?.iconName ?? viewModel.detectedDataType.iconName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if let detail = contentDetail {
                        Text(detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isEditingInput ? 90 : 0))
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "generator.editContent", defaultValue: "Edit content"))
        .accessibilityValue(viewModel.inputText)
    }

    private var contentDetail: String? {
        if let platform = viewModel.urlMetadata?.platform {
            return platform
        }
        let input = viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let summary = DataTypeDetector.summarize(input, for: viewModel.detectedDataType)
        // A summary that just echoes the line above it is noise — name the type instead.
        if let summary, !input.localizedCaseInsensitiveContains(summary) {
            return summary
        }
        return viewModel.detectedDataType.displayName
    }

    private var autoCaption: String {
        viewModel.currentInput.flatMap { CaptionGenerator.defaultCaption(for: $0) } ?? ""
    }

    // MARK: - Actions

    private var actionRow: some View {
        HStack(spacing: 11) {
            Button {
                Task { await performSave() }
            } label: {
                HStack(spacing: 9) {
                    if isExporting {
                        ProgressView()
                    } else {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 17, weight: .semibold))
                        Text(String(localized: "action.saveQR", defaultValue: "Save QR Code"))
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundStyle(Color(red: 0.294, green: 0.227, blue: 0.525))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    Capsule().fill(.white)
                        .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                )
            }
            .buttonStyle(.plain)
            .disabled(isExporting || !canExport)
            .opacity(canExport ? 1 : 0.55)

            secondaryAction(
                systemImage: copiedFeedback ? "checkmark" : "doc.on.doc",
                label: String(localized: "action.copyQR", defaultValue: "Copy QR Code")
            ) {
                Task { await performCopy() }
            }

            secondaryAction(
                systemImage: "square.and.arrow.up",
                label: String(localized: "action.share", defaultValue: "Share")
            ) {
                Task { await performShare() }
            }
        }
    }

    private func secondaryAction(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(Circle().fill(.white.opacity(0.2)))
        }
        .buttonStyle(.plain)
        .disabled(isExporting || !canExport)
        .opacity(canExport ? 1 : 0.55)
        .accessibilityLabel(label)
    }

    private var canExport: Bool {
        guard viewModel.hasValidInput else { return false }
        if selectedFormat.requiresPro && !purchaseManager.isPro { return false }
        return purchaseManager.isExportSizeAvailable(selectedSize)
    }

    private var exportConfiguration: ExportConfiguration {
        ExportConfiguration(
            format: selectedFormat,
            size: selectedSize,
            includeBackground: viewModel.configuration.backgroundType == .white
        )
    }

    private func performSave() async {
        isExporting = true
        do {
            let url = try await viewModel.saveToFile(config: exportConfiguration)
            await MainActor.run { recordHistoryIfEligible() }

            #if os(macOS)
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
            #else
            await MainActor.run {
                exportedFileURL = url
                showShareSheet = true
            }
            #endif
        } catch {
            await MainActor.run { viewModel.error = .exportFailed(error.localizedDescription) }
        }
        await MainActor.run { isExporting = false }
    }

    private func performCopy() async {
        isExporting = true
        do {
            try await viewModel.exportService.copyToClipboard(
                input: QRInput(content: viewModel.inputText),
                configuration: viewModel.configuration,
                size: CGFloat(selectedSize.width),
                captionText: viewModel.resolvedCaptionText
            )

            await MainActor.run {
                recordHistoryIfEligible()
                withAnimation { copiedFeedback = true }
            }

            try? await Task.sleep(nanoseconds: 2_000_000_000)

            await MainActor.run { withAnimation { copiedFeedback = false } }
        } catch {
            await MainActor.run { viewModel.error = .exportFailed(error.localizedDescription) }
        }
        await MainActor.run { isExporting = false }
    }

    private func performShare() async {
        isExporting = true
        do {
            let url = try await viewModel.saveToFile(config: exportConfiguration)
            await MainActor.run { recordHistoryIfEligible() }

            #if os(macOS)
            await MainActor.run {
                let picker = NSSharingServicePicker(items: [url])
                if let window = NSApp.keyWindow,
                   let contentView = window.contentView {
                    picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
                }
            }
            #else
            await MainActor.run {
                exportedFileURL = url
                showShareSheet = true
            }
            #endif
        } catch {
            await MainActor.run { viewModel.error = .exportFailed(error.localizedDescription) }
        }
        await MainActor.run { isExporting = false }
    }

    @MainActor
    private func recordHistoryIfEligible() {
        guard purchaseManager.isPro else { return }
        viewModel.recordHistory(in: modelContext)
    }
}

// MARK: - Compact Logo Drop Zone

struct CompactLogoDropZone: View {
    @Binding var logoData: Data?
    @State private var isTargeted = false
    @State private var showPhotoPicker = false
    @State private var showFilePicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        HStack(spacing: 12) {
            // Current logo preview (if any)
            if let logoData, let image = platformImage(from: logoData) {
                image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(.secondary.opacity(0.3), lineWidth: 1)
                    )
            }

            // Drop zone
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])
                    )
                    .foregroundStyle(isTargeted ? .accent : .secondary.opacity(0.4))
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isTargeted ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.05))
                    )

                HStack(spacing: 6) {
                    Image(systemName: isTargeted ? "arrow.down.circle.fill" : "photo.badge.plus")
                        .font(.caption)
                        .foregroundStyle(isTargeted ? .accent : .secondary)
                        .symbolEffect(.bounce, value: isTargeted)

                    Text(isTargeted
                         ? String(localized: "logo.release", defaultValue: "Release to add")
                         : (logoData == nil
                            ? String(localized: "logo.dropOrSelect", defaultValue: "Drop image or click to select")
                            : String(localized: "logo.dropToReplace", defaultValue: "Drop to replace")))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
            }
            .frame(height: 44)
            .onDrop(of: [.image], isTargeted: $isTargeted) { providers in
                handleImageDrop(providers: providers)
            }
            .onTapGesture {
                #if os(macOS)
                // On macOS, show file picker directly (more common workflow)
                showFilePicker = true
                #else
                // On iOS, show photo picker (more common workflow)
                showPhotoPicker = true
                #endif
            }
            .contextMenu {
                Button {
                    showPhotoPicker = true
                } label: {
                    Label(
                        String(localized: "logo.fromPhotos", defaultValue: "From Photos"),
                        systemImage: "photo.on.rectangle"
                    )
                }

                Button {
                    showFilePicker = true
                } label: {
                    Label(
                        String(localized: "logo.fromFiles", defaultValue: "From Files"),
                        systemImage: "folder"
                    )
                }
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, newValue in
            Task {
                await loadSelectedPhoto(newValue)
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.image, .png, .jpeg, .gif, .heic, .svg],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }

    private func handleImageDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
            if let data = data {
                DispatchQueue.main.async {
                    self.logoData = processImageData(data)
                }
            }
        }

        return true
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            if let data = try? Data(contentsOf: url) {
                logoData = processImageData(data)
            }

        case .failure:
            break
        }
    }

    private func loadSelectedPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }

        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                await MainActor.run {
                    self.logoData = processImageData(data)
                }
            }
        } catch {
            // Handle error silently
        }
    }

    private func processImageData(_ data: Data) -> Data? {
        #if os(macOS)
        guard let image = NSImage(data: data) else { return nil }
        let maxSize: CGFloat = 512

        if image.size.width > maxSize || image.size.height > maxSize {
            let scale = min(maxSize / image.size.width, maxSize / image.size.height)
            let newSize = NSSize(
                width: image.size.width * scale,
                height: image.size.height * scale
            )

            let resizedImage = NSImage(size: newSize)
            resizedImage.lockFocus()
            image.draw(
                in: NSRect(origin: .zero, size: newSize),
                from: NSRect(origin: .zero, size: image.size),
                operation: .copy,
                fraction: 1.0
            )
            resizedImage.unlockFocus()

            return resizedImage.tiffRepresentation
        }

        return data
        #else
        guard let image = UIImage(data: data) else { return nil }
        let maxSize: CGFloat = 512

        if image.size.width > maxSize || image.size.height > maxSize {
            let scale = min(maxSize / image.size.width, maxSize / image.size.height)
            let newSize = CGSize(
                width: image.size.width * scale,
                height: image.size.height * scale
            )

            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()

            return resizedImage?.pngData()
        }

        return data
        #endif
    }

    private func platformImage(from data: Data) -> Image? {
        #if os(macOS)
        guard let nsImage = NSImage(data: data) else { return nil }
        return Image(nsImage: nsImage)
        #else
        guard let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
        #endif
    }
}

// MARK: - QR Preview Background

struct QRPreviewBackground: View {
    var body: some View {
        Canvas { context, size in
            let tileSize: CGFloat = 8
            let rows = Int(ceil(size.height / tileSize))
            let cols = Int(ceil(size.width / tileSize))

            for row in 0..<rows {
                for col in 0..<cols {
                    let isLight = (row + col) % 2 == 0
                    let rect = CGRect(
                        x: CGFloat(col) * tileSize,
                        y: CGFloat(row) * tileSize,
                        width: tileSize,
                        height: tileSize
                    )
                    context.fill(
                        Path(rect),
                        with: .color(isLight ? Color(white: 0.95) : Color(white: 0.88))
                    )
                }
            }
        }
    }
}

// MARK: - Format Help View

struct FormatHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            FormatHelpContent()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "action.done", defaultValue: "Done")) {
                            dismiss()
                        }
                    }
                }
        }
    }
}

struct FormatExample: Identifiable {
    let id = UUID()
    let type: String
    let icon: String
    let title: String
    let description: String
    let examples: [(label: String, value: String)]

    static let allExamples: [FormatExample] = [
        FormatExample(
            type: "url",
            icon: "link",
            title: String(localized: "help.url.title", defaultValue: "URL / Website"),
            description: String(localized: "help.url.description", defaultValue: "Links to websites open directly in browser when scanned."),
            examples: [
                ("Simple", "https://example.com"),
                ("With path", "https://example.com/page?param=value")
            ]
        ),
        FormatExample(
            type: "social",
            icon: "at",
            title: String(localized: "help.social.title", defaultValue: "Social Profiles"),
            description: String(localized: "help.social.description", defaultValue: "Links to social media profiles. The app auto-detects the platform and handle."),
            examples: [
                ("Instagram", "https://instagram.com/username"),
                ("X (Twitter)", "https://x.com/username"),
                ("LinkedIn", "https://linkedin.com/in/username"),
                ("TikTok", "https://tiktok.com/@username")
            ]
        ),
        FormatExample(
            type: "deeplink",
            icon: "app.badge",
            title: String(localized: "help.deepLink.title", defaultValue: "App Links"),
            description: String(localized: "help.deepLink.description", defaultValue: "Links that open directly in specific apps like Zoom, Spotify, or Teams."),
            examples: [
                ("Zoom Meeting", "https://zoom.us/j/1234567890"),
                ("Spotify", "https://open.spotify.com/track/..."),
                ("Google Meet", "https://meet.google.com/abc-defg-hij")
            ]
        ),
        FormatExample(
            type: "email",
            icon: "envelope",
            title: String(localized: "help.email.title", defaultValue: "Email"),
            description: String(localized: "help.email.description", defaultValue: "Opens email composer with pre-filled recipient."),
            examples: [
                ("Simple", "contact@example.com"),
                ("With mailto:", "mailto:contact@example.com")
            ]
        ),
        FormatExample(
            type: "phone",
            icon: "phone",
            title: String(localized: "help.phone.title", defaultValue: "Phone Number"),
            description: String(localized: "help.phone.description", defaultValue: "Initiates a phone call when scanned."),
            examples: [
                ("International", "+1 555 123 4567"),
                ("With tel:", "tel:+15551234567")
            ]
        ),
        FormatExample(
            type: "sms",
            icon: "message",
            title: String(localized: "help.sms.title", defaultValue: "SMS"),
            description: String(localized: "help.sms.description", defaultValue: "Opens messaging app with pre-filled number."),
            examples: [
                ("Simple", "sms:+15551234567"),
                ("With message", "sms:+15551234567?body=Hello")
            ]
        ),
        FormatExample(
            type: "wifi",
            icon: "wifi",
            title: String(localized: "help.wifi.title", defaultValue: "WiFi Network"),
            description: String(localized: "help.wifi.description", defaultValue: "Allows one-tap WiFi connection (iOS 11+, Android)."),
            examples: [
                ("WPA/WPA2", "WIFI:T:WPA;S:NetworkName;P:password123;;"),
                ("Open network", "WIFI:T:nopass;S:FreeWiFi;;"),
                ("Hidden", "WIFI:T:WPA;S:HiddenNet;P:secret;H:true;;")
            ]
        ),
        FormatExample(
            type: "geo",
            icon: "location",
            title: String(localized: "help.geo.title", defaultValue: "Location"),
            description: String(localized: "help.geo.description", defaultValue: "Opens maps app at specific coordinates."),
            examples: [
                ("Coordinates", "40.7128, -74.0060"),
                ("With geo:", "geo:48.8584,2.2945")
            ]
        ),
        FormatExample(
            type: "vcard",
            icon: "person.crop.rectangle",
            title: String(localized: "help.vcard.title", defaultValue: "Contact (vCard)"),
            description: String(localized: "help.vcard.description", defaultValue: "Adds contact information to address book."),
            examples: [
                ("Basic", """
BEGIN:VCARD
VERSION:3.0
N:Doe;John
FN:John Doe
TEL:+1-555-123-4567
EMAIL:john@example.com
END:VCARD
""")
            ]
        ),
        FormatExample(
            type: "text",
            icon: "text.alignleft",
            title: String(localized: "help.text.title", defaultValue: "Plain Text"),
            description: String(localized: "help.text.description", defaultValue: "Any text content that doesn't match other formats. you'll need to handle this yourself"),
            examples: [
                ("Message", "Hello, scan me!"),
                ("Multiline", "Line 1\nLine 2\nLine 3")
            ]
        )
    ]
}

struct FormatExampleCard: View {
    let example: FormatExample
    @State private var copiedIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: example.icon)
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28)

                Text(example.title)
                    .font(.headline)
            }

            Text(example.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Examples
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(example.examples.enumerated()), id: \.offset) { index, item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            Text(item.value)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(4)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Button {
                                copyToClipboard(item.value, index: index)
                            } label: {
                                Image(systemName: copiedIndex == index ? "checkmark" : "doc.on.doc")
                                    .font(.caption)
                                    .foregroundStyle(copiedIndex == index ? .green : Color.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.1))
                        )
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.05))
        )
    }

    private func copyToClipboard(_ text: String, index: Int) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif

        withAnimation {
            copiedIndex = index
        }

        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation {
                copiedIndex = nil
            }
        }
    }
}

// MARK: - Share Sheet (iOS)

#if os(iOS)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

// MARK: - Preview

#Preview {
    GeneratorView()
        .environmentObject(PurchaseManager.shared)
        .environment(DeepLinkHandler())
}

#Preview("Help Sheet") {
    FormatHelpView()
}
