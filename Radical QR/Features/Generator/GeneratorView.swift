import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Main QR code generator view with inline customization
struct GeneratorView: View {
    @StateObject private var viewModel = GeneratorViewModel()
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(DeepLinkHandler.self) private var deepLinkHandler
    @Environment(\.modelContext) private var modelContext

    @State private var copiedFeedback = false
    @State private var showHelpSheet = false
    @State private var exportMode: ExportMode = .export
    @State private var selectedFormat: ExportFormat = .png
    @State private var selectedSize: ExportSize = .medium
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var exportedFileURL: URL?
    @State private var showEyeStylePaywall = false
    #if os(macOS)
    @State private var isGlobalDropTargeted = false
    #endif

    private let inputAnchorID = "input-section"

    enum ExportMode: String, CaseIterable {
        case copy
        case export

        var label: String {
            switch self {
            case .copy: String(localized: "mode.copy", defaultValue: "Copy")
            case .export: String(localized: "mode.export", defaultValue: "Export")
            }
        }
    }

    var body: some View {
        ZStack {
            GradientBackground()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        // Header
                        headerSection

                        // Input zone
                        inputSection

                        // QR Preview + Inline Customization
                        if viewModel.hasValidInput {
                            VStack(spacing: 0) {
                                // QR Preview Card
                                previewCard

                                // Inline Customization (always visible)
                                inlineCustomization
                            }
                            .cardStyle()
                        }

                        // Recent history (Pro) — quick reload for variants
                        if purchaseManager.isPro {
                            RecentHistoryStrip { item in
                                viewModel.loadFromHistory(item)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                }
                .onChange(of: viewModel.hasValidInput) { _, hasInput in
                    guard hasInput else { return }
                    scrollInputToTop(proxy: proxy)
                }
                .onChange(of: viewModel.inputText) { oldValue, newValue in
                    // Scroll when new content arrives (e.g. D&D, Services, Share)
                    // but not on every keystroke (only when transitioning from empty
                    // or when the change is large, indicating external input)
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
            // Dismiss keyboard when tapping outside text fields
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        #endif
        #if os(iOS)
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

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "generator.title", defaultValue: "QR Code Generator"))
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)

                Text(String(localized: "generator.subtitle", defaultValue: "No tracking. No storage. Just ephemeral QR codes."))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
            }

            Spacer()

            Button {
                showHelpSheet = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Input Section

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

    // MARK: - Data Type Summary (shown above QR preview)

    private var dataTypeSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                let metadata = viewModel.urlMetadata
                Image(systemName: metadata?.iconName ?? viewModel.detectedDataType.iconName)
                Text(metadata?.platform ?? viewModel.detectedDataType.displayName)
                    .fontWeight(.medium)

                Spacer()

                Text(metadata != nil
                     ? (metadata?.category == .socialProfile
                        ? String(localized: "dataType.url.social", defaultValue: "Social Profile")
                        : String(localized: "dataType.url.deepLink", defaultValue: "App Link"))
                     : viewModel.detectedDataType.description)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

            if let summary = DataTypeDetector.summarize(viewModel.inputText, for: viewModel.detectedDataType) {
                Text(summary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    // MARK: - Preview Card

    private var previewCard: some View {
        VStack(spacing: 12) {
            // Data type summary above the QR
            dataTypeSummary
                .padding(.horizontal, 16)
                .padding(.top, 16)

            // QR Code Image with background to show transparency
            ZStack {
                // Light gray background to visualize QR transparency
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.9))
                    .frame(width: 272, height: 272)

                if let image = viewModel.previewImage {
                    image
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 240, maxHeight: 240)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else if viewModel.isGenerating {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(width: 240, height: 240)
                } else {
                    Rectangle()
                        .fill(.secondary.opacity(0.1))
                        .frame(width: 240, height: 240)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.previewImage != nil)

            // Export section
            exportSection
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
    }

    // MARK: - Export Section

    private var exportSection: some View {
        VStack(spacing: 16) {
            // Mode toggle (Copy / Export)
            Picker("", selection: $exportMode) {
                ForEach(ExportMode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            // Size + Format selection (format only in export mode)
            HStack(alignment: .top, spacing: 16) {
                sizeSelector
                    .frame(maxWidth: .infinity, alignment: .leading)

                if exportMode == .export {
                    formatSelector
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: exportMode)

            // Action button
            actionButton
        }
    }

    private var sizeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(localized: "export.size", defaultValue: "Size"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                if !purchaseManager.isPro {
                    Text(String(localized: "export.sizeLimit", defaultValue: "Max \(FeatureLimit.freeMaxExportSize)px free"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ExportSize.allSizes, id: \.width) { size in
                        InlineSizeButton(
                            size: size,
                            isSelected: selectedSize == size,
                            isLocked: !purchaseManager.isExportSizeAvailable(size)
                        ) {
                            selectedSize = size
                        }
                    }
                }
            }
        }
    }

    private var formatSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "export.format", defaultValue: "Format"))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ExportFormat.allCases) { format in
                        InlineFormatButton(
                            format: format,
                            isSelected: selectedFormat == format,
                            isLocked: format.requiresPro && !purchaseManager.isPro
                        ) {
                            selectedFormat = format
                        }
                    }
                }
            }
        }
    }

    private var actionButton: some View {
        VStack(spacing: 8) {
            // Primary action button
            Button {
                Task {
                    await performAction()
                }
            } label: {
                HStack {
                    if isExporting {
                        ProgressView()
                            .tint(.white)
                    } else if copiedFeedback {
                        Image(systemName: "checkmark")
                        Text(String(localized: "action.copied", defaultValue: "Copied!"))
                    } else {
                        Image(systemName: exportMode == .copy ? "doc.on.doc" : "square.and.arrow.down")
                        Text(exportMode == .copy
                             ? String(localized: "action.copyQR", defaultValue: "Copy QR Code")
                             : String(localized: "action.saveQR", defaultValue: "Save QR Code"))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(copiedFeedback ? .green : .accentColor)
            .controlSize(.large)
            .disabled(isExporting || !canPerformAction)

            // Share button (only in export mode)
            if exportMode == .export {
                Button {
                    Task {
                        await performShare()
                    }
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text(String(localized: "action.share", defaultValue: "Share"))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isExporting || !canPerformAction)
            }
        }
    }

    private var canPerformAction: Bool {
        guard viewModel.hasValidInput else { return false }

        if exportMode == .export {
            if selectedFormat.requiresPro && !purchaseManager.isPro {
                return false
            }
        }

        if !purchaseManager.isExportSizeAvailable(selectedSize) {
            return false
        }

        return true
    }

    private func performAction() async {
        isExporting = true

        do {
            if exportMode == .copy {
                try await viewModel.exportService.copyToClipboard(
                    input: QRInput(content: viewModel.inputText),
                    configuration: viewModel.configuration,
                    size: CGFloat(selectedSize.width),
                    captionText: viewModel.resolvedCaptionText
                )

                await MainActor.run {
                    recordHistoryIfEligible()
                    withAnimation {
                        copiedFeedback = true
                    }
                }

                try? await Task.sleep(nanoseconds: 2_000_000_000)

                await MainActor.run {
                    withAnimation {
                        copiedFeedback = false
                    }
                }
            } else {
                let config = ExportConfiguration(
                    format: selectedFormat,
                    size: selectedSize,
                    includeBackground: viewModel.configuration.backgroundType == .white
                )

                let url = try await viewModel.saveToFile(config: config)

                await MainActor.run { recordHistoryIfEligible() }

                #if os(macOS)
                NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
                #else
                await MainActor.run {
                    exportedFileURL = url
                    showShareSheet = true
                }
                #endif
            }
        } catch {
            await MainActor.run {
                viewModel.error = .exportFailed(error.localizedDescription)
            }
        }

        await MainActor.run {
            isExporting = false
        }
    }

    @MainActor
    private func recordHistoryIfEligible() {
        guard purchaseManager.isPro else { return }
        viewModel.recordHistory(in: modelContext)
    }

    private func performShare() async {
        isExporting = true

        do {
            let config = ExportConfiguration(
                format: selectedFormat,
                size: selectedSize,
                includeBackground: viewModel.configuration.backgroundType == .white
            )

            let url = try await viewModel.saveToFile(config: config)

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
            await MainActor.run {
                viewModel.error = .exportFailed(error.localizedDescription)
            }
        }

        await MainActor.run {
            isExporting = false
        }
    }

    // MARK: - Inline Customization

    private var inlineCustomization: some View {
        VStack(spacing: 0) {
            // Divider
            Rectangle()
                .fill(.secondary.opacity(0.2))
                .frame(height: 1)

            VStack(spacing: 16) {
                // Compact Color/Style Row
                compactStyleSection

                // Compact Roundness Row
                compactRoundnessSection

                // Compact Background Row
                compactBackgroundSection

                // Logo Section (Pro) - Compacted
                compactLogoSection

                // Caption Section
                compactCaptionSection
            }
            .padding(16)
        }
    }

    // MARK: - Compact Style Section

    private var compactStyleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(localized: "customization.style", defaultValue: "Style"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                // Style mode toggle
                Picker("", selection: Binding(
                    get: { isGradientMode },
                    set: { newValue in
                        if newValue {
                            if case .solid(let color) = viewModel.configuration.foregroundStyle {
                                viewModel.configuration.foregroundStyle = .gradient(GradientConfiguration(
                                    startColor: color,
                                    endColor: .indigo
                                ))
                            }
                        } else {
                            if case .gradient(let config) = viewModel.configuration.foregroundStyle {
                                viewModel.configuration.foregroundStyle = .solid(config.startColor)
                            }
                        }
                    }
                )) {
                    Text(String(localized: "style.solid", defaultValue: "Solid")).tag(false)
                    Text(String(localized: "style.gradient", defaultValue: "Gradient")).tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }

            // Color swatches in horizontal scroll
            if isGradientMode {
                compactGradientPicker
            } else {
                compactColorPicker
            }
        }
    }

    private var isGradientMode: Bool {
        if case .gradient = viewModel.configuration.foregroundStyle {
            return true
        }
        return false
    }

    private var compactColorPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SerializableColor.freeColors, id: \.self) { color in
                    CompactColorSwatch(
                        color: color,
                        isSelected: isColorSelected(color)
                    ) {
                        viewModel.configuration.foregroundStyle = .solid(color)
                    }
                }

                if purchaseManager.isPro {
                    ColorPicker("", selection: Binding(
                        get: { currentSolidColor.color },
                        set: { viewModel.configuration.foregroundStyle = .solid(SerializableColor($0)) }
                    ), supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 32, height: 32)
                }
            }
        }
    }

    private var currentSolidColor: SerializableColor {
        if case .solid(let color) = viewModel.configuration.foregroundStyle {
            return color
        }
        return .black
    }

    private func isColorSelected(_ color: SerializableColor) -> Bool {
        if case .solid(let current) = viewModel.configuration.foregroundStyle {
            return current == color
        }
        return false
    }

    private var compactGradientPicker: some View {
        VStack(spacing: 12) {
            // Gradient type picker (Pro gets Angular & Diamond)
            if purchaseManager.isPro {
                HStack(spacing: 6) {
                    ForEach(GradientConfiguration.GradientType.allCases, id: \.self) { type in
                        CompactGradientTypeButton(
                            type: type,
                            isSelected: currentGradientType == type
                        ) {
                            updateGradientType(type)
                        }
                    }
                }
            }

            // Preset gradients
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(GradientConfiguration.freeGradients, id: \.self) { preset in
                        CompactGradientSwatch(
                            gradient: preset,
                            isSelected: isGradientSelected(preset)
                        ) {
                            viewModel.configuration.foregroundStyle = .gradient(preset)
                        }
                    }

                    // Custom gradient color pickers for Pro
                    if purchaseManager.isPro {
                        Divider()
                            .frame(height: 24)
                            .padding(.horizontal, 4)

                        // Start color picker
                        VStack(spacing: 2) {
                            ColorPicker("", selection: Binding(
                                get: { currentGradientConfig.startColor.color },
                                set: { updateGradientStartColor(SerializableColor($0)) }
                            ), supportsOpacity: false)
                            .labelsHidden()
                            .frame(width: 32, height: 32)

                            Text(String(localized: "gradient.start", defaultValue: "Start"))
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }

                        // End color picker
                        VStack(spacing: 2) {
                            ColorPicker("", selection: Binding(
                                get: { currentGradientConfig.endColor.color },
                                set: { updateGradientEndColor(SerializableColor($0)) }
                            ), supportsOpacity: false)
                            .labelsHidden()
                            .frame(width: 32, height: 32)

                            Text(String(localized: "gradient.end", defaultValue: "End"))
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Angle slider for linear gradient (Pro)
            if purchaseManager.isPro && currentGradientType == .linear {
                HStack(spacing: 8) {
                    Text(String(localized: "gradient.angle", defaultValue: "Angle"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Slider(
                        value: Binding(
                            get: { currentGradientConfig.angle },
                            set: { updateGradientAngle($0) }
                        ),
                        in: 0...360,
                        step: 15
                    )
                    .tint(currentGradientConfig.startColor.color)

                    Text("\(Int(currentGradientConfig.angle))°")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 32)
                }
            }
        }
    }

    private var currentGradientConfig: GradientConfiguration {
        if case .gradient(let config) = viewModel.configuration.foregroundStyle {
            return config
        }
        return .purpleViolet
    }

    private var currentGradientType: GradientConfiguration.GradientType {
        currentGradientConfig.type
    }

    private func updateGradientType(_ type: GradientConfiguration.GradientType) {
        if case .gradient(var config) = viewModel.configuration.foregroundStyle {
            config.type = type
            viewModel.configuration.foregroundStyle = .gradient(config)
        }
    }

    private func updateGradientStartColor(_ color: SerializableColor) {
        if case .gradient(var config) = viewModel.configuration.foregroundStyle {
            config.startColor = color
            viewModel.configuration.foregroundStyle = .gradient(config)
        }
    }

    private func updateGradientEndColor(_ color: SerializableColor) {
        if case .gradient(var config) = viewModel.configuration.foregroundStyle {
            config.endColor = color
            viewModel.configuration.foregroundStyle = .gradient(config)
        }
    }

    private func updateGradientAngle(_ angle: Double) {
        if case .gradient(var config) = viewModel.configuration.foregroundStyle {
            config.angle = angle
            viewModel.configuration.foregroundStyle = .gradient(config)
        }
    }

    private func isGradientSelected(_ preset: GradientConfiguration) -> Bool {
        if case .gradient(let current) = viewModel.configuration.foregroundStyle {
            return current.startColor == preset.startColor && current.endColor == preset.endColor
        }
        return false
    }

    // MARK: - Compact Roundness Section

    private var compactRoundnessSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "shape.title", defaultValue: "Shape"))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            presetRow(
                label: String(localized: "roundness.modules", defaultValue: "Modules"),
                presets: roundnessPresets,
                value: viewModel.configuration.roundness,
                formatValue: { "\(Int($0 * 100))%" },
                onChange: { value in
                    viewModel.configuration.roundness = value
                }
            )

            eyeStyleRow

            presetRow(
                label: String(localized: "eye.size.label", defaultValue: "Eye Size"),
                presets: eyeSizePresets,
                value: viewModel.configuration.eyeScale,
                formatValue: { "\(Int($0 * 100))%" },
                onChange: { value in
                    viewModel.configuration.eyeScale = value
                }
            )
        }
    }

    // Eye shape picker (Square / Rounded free, Dot / Leaf Pro).
    private var eyeStyleRow: some View {
        HStack(spacing: 8) {
            Text(String(localized: "eye.style.label", defaultValue: "Eyes"))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .leading)

            ForEach(QRCodeConfiguration.EyeStyle.allCases, id: \.self) { eyeStyle in
                let locked = eyeStyle.isPro && !purchaseManager.isPro
                let selected = viewModel.configuration.eyeStyle == eyeStyle
                Button {
                    if locked { showEyeStylePaywall = true }
                    else { viewModel.configuration.eyeStyle = eyeStyle }
                } label: {
                    HStack(spacing: 3) {
                        Text(eyeStyle.displayName).font(.caption2)
                        if locked {
                            Image(systemName: "lock.fill").font(.system(size: 8))
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .background(
                        Capsule().fill(selected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                    )
                    .overlay(
                        Capsule().strokeBorder(selected ? Color.accentColor : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .foregroundStyle(selected ? .primary : .secondary)
            }
        }
        .sheet(isPresented: $showEyeStylePaywall) {
            PaywallView(feature: .eyeStyles)
        }
    }

    @ViewBuilder
    private func presetRow(
        label: String,
        presets: [(label: String, value: CGFloat)],
        value: CGFloat,
        formatValue: (CGFloat) -> String,
        onChange: @escaping (CGFloat) -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)

            HStack(spacing: 6) {
                ForEach(presets, id: \.value) { preset in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            onChange(preset.value)
                        }
                    } label: {
                        Text(preset.label)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(isPresetSelected(value, preset: preset.value)
                                          ? Color.accentColor.opacity(0.2)
                                          : Color.secondary.opacity(0.1))
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        isPresetSelected(value, preset: preset.value)
                                            ? Color.accentColor : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(
                        isPresetSelected(value, preset: preset.value) ? .primary : .secondary
                    )
                }
            }

            #if os(macOS)
            Spacer()

            Text(formatValue(value))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
            #endif
        }
    }

    private var roundnessPresets: [(label: String, value: CGFloat)] {
        [
            (String(localized: "roundness.sharp", defaultValue: "Sharp"), 0),
            (String(localized: "roundness.slight", defaultValue: "Slight"), 0.3),
            (String(localized: "roundness.rounded", defaultValue: "Rounded"), 0.6),
            (String(localized: "roundness.circular", defaultValue: "Circular"), 1.0)
        ]
    }

    private var eyeSizePresets: [(label: String, value: CGFloat)] {
        [
            (String(localized: "eye.size.compact", defaultValue: "Compact"), 0.75),
            (String(localized: "eye.size.medium", defaultValue: "Medium"), 0.9),
            (String(localized: "eye.size.full", defaultValue: "Full"), 1.0)
        ]
    }

    private func isPresetSelected(_ current: CGFloat, preset: CGFloat) -> Bool {
        abs(current - preset) < 0.05
    }

    // MARK: - Compact Background Section

    private var compactBackgroundSection: some View {
        HStack {
            Text(String(localized: "customization.background", defaultValue: "Background"))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 8) {
                CompactBackgroundButton(
                    type: .white,
                    isSelected: viewModel.configuration.backgroundType == .white
                ) {
                    viewModel.configuration.backgroundType = .white
                }

                CompactBackgroundButton(
                    type: .transparent,
                    isSelected: viewModel.configuration.backgroundType == .transparent
                ) {
                    viewModel.configuration.backgroundType = .transparent
                }

                // Logo cutout option - only show when logo is present and user is Pro
                if purchaseManager.isPro && viewModel.configuration.logoData != nil {
                    CompactBackgroundButton(
                        type: .transparentWithLogoCutout,
                        isSelected: viewModel.configuration.backgroundType == .transparentWithLogoCutout
                    ) {
                        viewModel.configuration.backgroundType = .transparentWithLogoCutout
                    }
                }
            }
        }
    }

    // MARK: - Compact Logo Section

    private var compactLogoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(localized: "logo.title", defaultValue: "Logo"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                if !purchaseManager.isPro {
                    ProBadge()
                }

                Spacer()

                if purchaseManager.isPro && viewModel.configuration.logoData != nil {
                    Button(role: .destructive) {
                        withAnimation {
                            viewModel.configuration.logoData = nil
                        }
                    } label: {
                        Label(
                            String(localized: "logo.remove", defaultValue: "Remove"),
                            systemImage: "trash"
                        )
                        .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if purchaseManager.isPro {
                CompactLogoDropZone(logoData: $viewModel.configuration.logoData)
            } else {
                CompactProLockedButton(feature: .logoEmbedding)
            }
        }
    }

    // MARK: - Compact Caption Section

    private var compactCaptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(localized: "caption.title", defaultValue: "Caption"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Toggle("", isOn: $viewModel.configuration.showCaption)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            if viewModel.configuration.showCaption {
                let autoCaption = viewModel.currentInput.flatMap { CaptionGenerator.defaultCaption(for: $0) } ?? ""

                TextField(
                    autoCaption,
                    text: Binding(
                        get: { viewModel.configuration.captionText ?? "" },
                        set: { viewModel.configuration.captionText = $0.isEmpty ? nil : $0 }
                    )
                )
                .font(.caption)
                .textFieldStyle(.roundedBorder)

                // Size selector
                HStack(spacing: 8) {
                    Text(String(localized: "caption.size", defaultValue: "Size"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    ForEach(QRCodeConfiguration.CaptionSize.allCases, id: \.self) { size in
                        Button {
                            viewModel.configuration.captionSize = size
                        } label: {
                            Text(size.displayName)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(viewModel.configuration.captionSize == size
                                              ? Color.accentColor.opacity(0.2)
                                              : Color.secondary.opacity(0.1))
                                )
                                .overlay(
                                    Capsule()
                                        .strokeBorder(viewModel.configuration.captionSize == size
                                                      ? Color.accentColor : Color.clear, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(viewModel.configuration.captionSize == size ? .primary : .secondary)
                    }
                }

                // Fit-to-width toggle: shrink the caption so any text fits
                // the space under the QR code instead of being truncated.
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(String(localized: "caption.fitToWidth", defaultValue: "Fit to width"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(String(localized: "caption.fitToWidth.hint", defaultValue: "Shrink text so it always fits"))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    Toggle("", isOn: $viewModel.configuration.captionFitToWidth)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
            }
        }
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

// MARK: - Compact Color Swatch

struct CompactColorSwatch: View {
    let color: SerializableColor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color.color)
                    .frame(width: 32, height: 32)

                if isSelected {
                    Circle()
                        .strokeBorder(.white, lineWidth: 2)
                        .frame(width: 32, height: 32)

                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .shadow(radius: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Compact Gradient Swatch

struct CompactGradientSwatch: View {
    let gradient: GradientConfiguration
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [gradient.startColor.color, gradient.endColor.color],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 32)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isSelected ? .white : .clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Compact Gradient Type Button

struct CompactGradientTypeButton: View {
    let type: GradientConfiguration.GradientType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: type.iconName)
                    .font(.caption)

                Text(type.displayName)
                    .font(.system(size: 9))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .primary : .secondary)
    }
}

// MARK: - Compact Background Button

struct CompactBackgroundButton: View {
    let type: BackgroundType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                ZStack {
                    switch type {
                    case .white:
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white)
                            .frame(width: 16, height: 16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(.secondary.opacity(0.3), lineWidth: 0.5)
                            )
                    case .transparent:
                        // Mini checkerboard
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.secondary.opacity(0.2))
                            .frame(width: 16, height: 16)
                    case .transparentWithLogoCutout:
                        // Checkerboard with white center (logo cutout)
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.secondary.opacity(0.2))
                                .frame(width: 16, height: 16)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(.white)
                                .frame(width: 8, height: 8)
                        }
                    }
                }

                Text(type.displayName)
                    .font(.caption2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .primary : .secondary)
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

// MARK: - Compact Pro Locked Button

struct CompactProLockedButton: View {
    let feature: ProFeature
    @State private var showPaywall = false

    var body: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                Text(String(localized: "action.unlock", defaultValue: "Unlock"))
                    .font(.caption)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(.secondary)
        .sheet(isPresented: $showPaywall) {
            PaywallView(feature: feature)
        }
    }
}

// MARK: - Inline Size Button

struct InlineSizeButton: View {
    let size: ExportSize
    let isSelected: Bool
    let isLocked: Bool
    let action: () -> Void

    @State private var showPaywall = false

    var body: some View {
        Button {
            if isLocked {
                showPaywall = true
            } else {
                action()
            }
        } label: {
            HStack(spacing: 4) {
                Text(shortDisplayName)
                    .font(.caption2.monospacedDigit())

                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isLocked ? .secondary : (isSelected ? .primary : .secondary))
        .sheet(isPresented: $showPaywall) {
            PaywallView(feature: .unlimitedExportSize)
        }
    }

    private var shortDisplayName: String {
        "\(size.width)"
    }
}

// MARK: - Inline Format Button

struct InlineFormatButton: View {
    let format: ExportFormat
    let isSelected: Bool
    let isLocked: Bool
    let action: () -> Void

    @State private var showPaywall = false

    var body: some View {
        Button {
            if isLocked {
                showPaywall = true
            } else {
                action()
            }
        } label: {
            HStack(spacing: 4) {
                Text(format.displayName)
                    .font(.caption2.weight(.medium))

                if format.isVector {
                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isLocked ? .secondary : (isSelected ? .primary : .secondary))
        .sheet(isPresented: $showPaywall) {
            PaywallView(feature: .vectorExport)
        }
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
