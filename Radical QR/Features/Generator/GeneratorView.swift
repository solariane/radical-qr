import SwiftUI
import PhotosUI

/// Main QR code generator view with inline customization
struct GeneratorView: View {
    @StateObject private var viewModel = GeneratorViewModel()
    @EnvironmentObject private var purchaseManager: PurchaseManager

    @State private var showExportSheet = false
    @State private var copiedFeedback = false

    var body: some View {
        ZStack {
            GradientBackground()

            ScrollView {
                VStack(spacing: 20) {
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
                }
                .padding()
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showExportSheet) {
            ExportView(viewModel: viewModel)
        }
        .alert(item: $viewModel.error) { error in
            Alert(
                title: Text(String(localized: "error.title", defaultValue: "Error")),
                message: Text(error.localizedDescription),
                dismissButton: .default(Text(String(localized: "error.dismiss", defaultValue: "OK")))
            )
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(String(localized: "generator.title", defaultValue: "QR Code Generator"))
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Text(String(localized: "generator.subtitle", defaultValue: "No tracking. No storage. Just ephemeral QR codes."))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
        }
        .multilineTextAlignment(.center)
        .padding(.top, 20)
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(spacing: 0) {
            InputZone(
                text: $viewModel.inputText,
                onFileSelected: { url in
                    viewModel.handleFileDrop(url)
                },
                placeholder: String(localized: "generator.input.placeholder", defaultValue: "Enter URL, text, or drop a file...")
            )

            // Data type indicator
            if viewModel.hasValidInput {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.detectedDataType.iconName)
                    Text(viewModel.detectedDataType.displayName)

                    Spacer()

                    Text(viewModel.detectedDataType.description)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 4)
                .padding(.top, 12)
            }
        }
    }

    // MARK: - Preview Card

    private var previewCard: some View {
        VStack(spacing: 16) {
            // QR Code Image
            ZStack {
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
            .padding(.top, 16)

            // Quick action buttons
            quickActions
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        HStack(spacing: 12) {
            // Copy button
            Button {
                Task {
                    await viewModel.copyToClipboard()
                    withAnimation {
                        copiedFeedback = true
                    }
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    withAnimation {
                        copiedFeedback = false
                    }
                }
            } label: {
                Label(
                    copiedFeedback
                        ? String(localized: "action.copied", defaultValue: "Copied!")
                        : String(localized: "action.copy", defaultValue: "Copy"),
                    systemImage: copiedFeedback ? "checkmark" : "doc.on.doc"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(copiedFeedback ? .green : .accentColor)

            // Export button
            Button {
                showExportSheet = true
            } label: {
                Label(
                    String(localized: "action.export", defaultValue: "Export"),
                    systemImage: "square.and.arrow.up"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
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
            }
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(localized: "roundness.title", defaultValue: "Roundness"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(Int(viewModel.configuration.roundness * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                // Quick presets
                ForEach(roundnessPresets, id: \.value) { preset in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.configuration.roundness = preset.value
                        }
                    } label: {
                        Text(preset.label)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(isRoundnessSelected(preset.value) ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(isRoundnessSelected(preset.value) ? Color.accentColor : Color.clear, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isRoundnessSelected(preset.value) ? .primary : .secondary)
                }
            }
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

    private func isRoundnessSelected(_ value: CGFloat) -> Bool {
        abs(viewModel.configuration.roundness - value) < 0.05
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
            }
        }
    }

    // MARK: - Compact Logo Section

    private var compactLogoSection: some View {
        HStack {
            Text(String(localized: "logo.title", defaultValue: "Logo"))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            if !purchaseManager.isPro {
                ProBadge()
            }

            Spacer()

            if purchaseManager.isPro {
                if viewModel.configuration.logoData != nil {
                    HStack(spacing: 8) {
                        // Small logo preview
                        if let data = viewModel.configuration.logoData,
                           let image = platformImage(from: data) {
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }

                        Button(role: .destructive) {
                            withAnimation {
                                viewModel.configuration.logoData = nil
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    CompactLogoButton(logoData: $viewModel.configuration.logoData)
                }
            } else {
                CompactProLockedButton(feature: .logoEmbedding)
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

// MARK: - Compact Background Button

struct CompactBackgroundButton: View {
    let type: BackgroundType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                ZStack {
                    if type == .transparent {
                        // Mini checkerboard
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.secondary.opacity(0.2))
                            .frame(width: 16, height: 16)
                    } else {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white)
                            .frame(width: 16, height: 16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(.secondary.opacity(0.3), lineWidth: 0.5)
                            )
                    }
                }

                Text(type == .white
                     ? String(localized: "background.white", defaultValue: "White")
                     : String(localized: "background.transparent", defaultValue: "Clear"))
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

// MARK: - Compact Logo Button

struct CompactLogoButton: View {
    @Binding var logoData: Data?
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        Button {
            showPhotoPicker = true
        } label: {
            Label(
                String(localized: "logo.add", defaultValue: "Add"),
                systemImage: "plus.circle"
            )
            .font(.caption)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, newValue in
            Task {
                await loadSelectedPhoto(newValue)
            }
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

// MARK: - Preview

#Preview {
    GeneratorView()
        .environmentObject(PurchaseManager.shared)
}
