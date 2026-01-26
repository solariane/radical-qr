import SwiftUI

/// Panel for customizing QR code appearance
struct CustomizationPanel: View {
    @Binding var configuration: QRCodeConfiguration
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    @State private var styleMode: StyleMode = .solid

    enum StyleMode: String, CaseIterable {
        case solid
        case gradient

        var displayName: String {
            switch self {
            case .solid: String(localized: "style.solid", defaultValue: "Solid")
            case .gradient: String(localized: "style.gradient", defaultValue: "Gradient")
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Style mode picker
                    styleModeSection

                    Divider()

                    // Color/Gradient picker based on mode
                    colorSection

                    Divider()

                    // Background toggle
                    backgroundSection

                    Divider()

                    // Roundness slider
                    roundnessSection

                    Divider()

                    // Logo (Pro)
                    logoSection

                    // Preset gradients
                    if styleMode == .gradient {
                        Divider()
                        presetGradientsSection
                    }
                }
                .padding()
            }
            #if os(iOS)
            .background(Color(.systemGroupedBackground))
            #else
            .background(Color(nsColor: .controlBackgroundColor))
            #endif
            .navigationTitle(String(localized: "customization.title", defaultValue: "Customize"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.done", defaultValue: "Done")) {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Sync style mode with current configuration
            if case .gradient = configuration.foregroundStyle {
                styleMode = .gradient
            } else {
                styleMode = .solid
            }
        }
    }

    // MARK: - Style Mode Section

    private var styleModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "customization.style", defaultValue: "Style"))
                .sectionHeaderStyle()

            Picker(String(localized: "customization.style", defaultValue: "Style"), selection: $styleMode) {
                ForEach(StyleMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: styleMode) { _, newValue in
                switch newValue {
                case .solid:
                    if case .gradient(let config) = configuration.foregroundStyle {
                        configuration.foregroundStyle = .solid(config.startColor)
                    }
                case .gradient:
                    if case .solid(let color) = configuration.foregroundStyle {
                        configuration.foregroundStyle = .gradient(GradientConfiguration(
                            startColor: color,
                            endColor: .indigo
                        ))
                    }
                }
            }
        }
    }

    // MARK: - Color Section

    @ViewBuilder
    private var colorSection: some View {
        switch styleMode {
        case .solid:
            solidColorSection
        case .gradient:
            gradientColorSection
        }
    }

    private var solidColorSection: some View {
        ColorPickerView(
            selectedColor: Binding(
                get: {
                    if case .solid(let color) = configuration.foregroundStyle {
                        return color
                    }
                    return .black
                },
                set: { newColor in
                    configuration.foregroundStyle = .solid(newColor)
                }
            )
        )
    }

    private var gradientColorSection: some View {
        GradientColorPickerView(
            gradient: Binding(
                get: {
                    if case .gradient(let config) = configuration.foregroundStyle {
                        return config
                    }
                    return .purpleViolet
                },
                set: { newGradient in
                    configuration.foregroundStyle = .gradient(newGradient)
                }
            )
        )
    }

    // MARK: - Background Section

    private var backgroundSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "customization.background", defaultValue: "Background"))
                .sectionHeaderStyle()

            HStack(spacing: 12) {
                BackgroundOptionButton(
                    type: .white,
                    isSelected: configuration.backgroundType == .white
                ) {
                    configuration.backgroundType = .white
                }

                BackgroundOptionButton(
                    type: .transparent,
                    isSelected: configuration.backgroundType == .transparent
                ) {
                    configuration.backgroundType = .transparent
                }

                // Logo cutout option - only show when logo is present and user is Pro
                if purchaseManager.isPro && configuration.logoData != nil {
                    BackgroundOptionButton(
                        type: .transparentWithLogoCutout,
                        isSelected: configuration.backgroundType == .transparentWithLogoCutout
                    ) {
                        configuration.backgroundType = .transparentWithLogoCutout
                    }
                }
            }
        }
    }

    // MARK: - Roundness Section

    private var roundnessSection: some View {
        RoundnessSlider(roundness: $configuration.roundness)
    }

    // MARK: - Logo Section

    private var logoSection: some View {
        LogoDropZone(logoData: $configuration.logoData)
    }

    // MARK: - Preset Gradients Section

    private var presetGradientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "customization.presets", defaultValue: "Presets"))
                .sectionHeaderStyle()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(GradientConfiguration.freeGradients, id: \.self) { preset in
                        GradientPresetButton(
                            gradient: preset,
                            isSelected: isGradientSelected(preset)
                        ) {
                            configuration.foregroundStyle = .gradient(preset)
                        }
                    }
                }
            }
        }
    }

    private func isGradientSelected(_ preset: GradientConfiguration) -> Bool {
        if case .gradient(let current) = configuration.foregroundStyle {
            return current.startColor == preset.startColor && current.endColor == preset.endColor
        }
        return false
    }
}

// MARK: - Background Option Button

struct BackgroundOptionButton: View {
    let type: BackgroundType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    // Checkerboard for transparent backgrounds
                    if type == .transparent || type == .transparentWithLogoCutout {
                        CheckerboardPattern()
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // White fill for white background
                    if type == .white {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white)
                            .frame(width: 50, height: 50)
                    }

                    // Border
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.secondary.opacity(0.3), lineWidth: 1)
                        .frame(width: 50, height: 50)

                    // White center for logo cutout
                    if type == .transparentWithLogoCutout {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white)
                            .frame(width: 20, height: 20)
                    }

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.tint)
                    }
                }

                Text(type.displayName)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Checkerboard Pattern

struct CheckerboardPattern: View {
    let size: CGFloat = 5

    var body: some View {
        Canvas { context, canvasSize in
            let rows = Int(canvasSize.height / size) + 1
            let cols = Int(canvasSize.width / size) + 1

            for row in 0..<rows {
                for col in 0..<cols {
                    let isLight = (row + col) % 2 == 0
                    let rect = CGRect(
                        x: CGFloat(col) * size,
                        y: CGFloat(row) * size,
                        width: size,
                        height: size
                    )
                    context.fill(
                        Path(rect),
                        with: .color(isLight ? .white : .gray.opacity(0.3))
                    )
                }
            }
        }
    }
}

// MARK: - Gradient Preset Button

struct GradientPresetButton: View {
    let gradient: GradientConfiguration
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [gradient.startColor.color, gradient.endColor.color],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 60, height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(isSelected ? .white : .clear, lineWidth: 3)
                )
                .shadow(color: gradient.startColor.color.opacity(0.4), radius: isSelected ? 6 : 0, y: 2)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Preview

#Preview {
    CustomizationPanel(configuration: .constant(.default))
        .environmentObject(PurchaseManager.shared)
}
