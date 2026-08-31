import SwiftUI

/// Color family of the customization rail: solid, gradient, background.
///
/// Every option paints itself. The two Pro escape hatches that cannot be a fixed
/// swatch — the free color picker and the gradient stops — are system
/// `ColorPicker`s dressed as tiles, so the row still reads as one vocabulary.
struct ColorGroupView: View {
    @Binding var configuration: QRCodeConfiguration
    let onLocked: (ProFeature) -> Void

    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.generatorMetrics) private var metrics

    private var isGradient: Bool {
        if case .gradient = configuration.foregroundStyle { return true }
        return false
    }

    private var solidColor: SerializableColor {
        if case .solid(let color) = configuration.foregroundStyle { return color }
        return .black
    }

    private var gradient: GradientConfiguration {
        if case .gradient(let config) = configuration.foregroundStyle { return config }
        return .purpleViolet
    }

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.rowGap) {
            solidRow
            gradientRow
            backgroundRow
        }
    }

    // MARK: - Solid

    private var solidRow: some View {
        VStack(alignment: .leading, spacing: metrics.labelGap) {
            SettingRowLabel(text: String(localized: "style.solid", defaultValue: "Solid"))

            TileRow {
                ForEach(SerializableColor.freeColors, id: \.self) { color in
                    SettingTile(
                        width: metrics.swatch,
                        height: metrics.swatch,
                        contentScale: 0.64,
                        isSelected: !isGradient && solidColor == color,
                        label: color.accessibilityName,
                        action: { configuration.foregroundStyle = .solid(color) }
                    ) {
                        Circle().fill(color.color)
                    }
                }

                if purchaseManager.isPro {
                    ColorPickerTile(
                        color: Binding(
                            get: { solidColor.color },
                            set: { configuration.foregroundStyle = .solid(SerializableColor($0)) }
                        ),
                        label: String(localized: "color.custom", defaultValue: "Custom color")
                    )
                } else {
                    SettingTile(
                        width: metrics.swatch,
                        height: metrics.swatch,
                        contentScale: 0.64,
                        isSelected: false,
                        isLocked: true,
                        label: String(localized: "color.custom", defaultValue: "Custom color"),
                        action: { onLocked(.fullColorPicker) }
                    ) {
                        Circle().fill(AngularGradient(colors: Self.wheel, center: .center))
                    }
                }
            }
        }
    }

    // MARK: - Gradient

    private var gradientRow: some View {
        VStack(alignment: .leading, spacing: metrics.labelGap) {
            SettingRowLabel(text: String(localized: "style.gradient", defaultValue: "Gradient"))

            TileRow {
                ForEach(GradientConfiguration.freeGradients, id: \.self) { preset in
                    SettingTile(
                        width: metrics.swatch,
                        height: metrics.swatch,
                        contentScale: 0.64,
                        isSelected: isGradient && gradient.matchesStops(of: preset),
                        label: preset.accessibilityName,
                        action: { configuration.foregroundStyle = .gradient(preset) }
                    ) {
                        Circle().fill(LinearGradient(
                            colors: [preset.startColor.color, preset.endColor.color],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                    }
                }

                if purchaseManager.isPro {
                    ColorPickerTile(
                        color: Binding(
                            get: { gradient.startColor.color },
                            set: { newColor in updateGradient { $0.startColor = SerializableColor(newColor) } }
                        ),
                        label: String(localized: "gradient.start", defaultValue: "Start")
                    )
                    ColorPickerTile(
                        color: Binding(
                            get: { gradient.endColor.color },
                            set: { newColor in updateGradient { $0.endColor = SerializableColor(newColor) } }
                        ),
                        label: String(localized: "gradient.end", defaultValue: "End")
                    )
                } else {
                    SettingTile(
                        width: metrics.swatch,
                        height: metrics.swatch,
                        contentScale: 0.64,
                        isSelected: false,
                        isLocked: true,
                        label: String(localized: "gradient.custom", defaultValue: "Custom gradient"),
                        action: { onLocked(.fullColorPicker) }
                    ) {
                        Circle().fill(AngularGradient(colors: Self.wheel, center: .center))
                    }
                }
            }

            if isGradient {
                gradientShapeRow
            }
        }
    }

    /// Gradient geometry, drawn rather than named: each tile paints the current
    /// stops with that type.
    @ViewBuilder
    private var gradientShapeRow: some View {
        TileRow {
            ForEach(GradientConfiguration.GradientType.allCases, id: \.self) { type in
                let locked = !purchaseManager.isPro && type != .linear && type != .radial
                SettingTile(
                    width: metrics.swatch,
                    height: metrics.swatch,
                    contentScale: 0.64,
                    isSelected: gradient.type == type,
                    isLocked: locked,
                    label: type.displayName,
                    action: {
                        if locked {
                            onLocked(.allGradientTypes)
                        } else {
                            updateGradient { $0.type = type }
                        }
                    }
                ) {
                    GradientTypeGlyph(
                        type: type,
                        colors: [gradient.startColor.color, gradient.endColor.color]
                    )
                }
            }
        }

        if purchaseManager.isPro && gradient.type == .linear {
            HStack(spacing: 10) {
                Image(systemName: "angle")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
                Slider(
                    value: Binding(
                        get: { gradient.angle },
                        set: { angle in updateGradient { $0.angle = angle } }
                    ),
                    in: 0...360,
                    step: 15
                )
                .tint(.white)
                Text("\(Int(gradient.angle))°")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(width: 34, alignment: .trailing)
            }
            .accessibilityLabel(String(localized: "gradient.angle", defaultValue: "Angle"))
        }
    }

    // MARK: - Background

    private var backgroundRow: some View {
        VStack(alignment: .leading, spacing: metrics.labelGap) {
            SettingRowLabel(text: String(localized: "customization.background", defaultValue: "Background"))

            HStack(spacing: metrics.tileGap) {
                ForEach(backgroundOptions, id: \.self) { type in
                    SettingTile(
                        width: metrics.tile,
                        height: metrics.tile,
                        isSelected: configuration.backgroundType == type,
                        label: type.displayName,
                        action: { configuration.backgroundType = type }
                    ) {
                        BackgroundGlyph(type: type)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var backgroundOptions: [BackgroundType] {
        var options: [BackgroundType] = [.white, .transparent]
        if purchaseManager.isPro && configuration.logoData != nil {
            options.append(.transparentWithLogoCutout)
        }
        return options
    }

    // MARK: - Helpers

    /// Mutates the gradient currently on screen, falling back to the default one
    /// when the code is still solid (so switching type also switches mode).
    private func updateGradient(_ mutate: (inout GradientConfiguration) -> Void) {
        var config = gradient
        mutate(&config)
        configuration.foregroundStyle = .gradient(config)
    }

    private static let wheel: [Color] = [.red, .yellow, .green, .cyan, .blue, .purple, .red]
}

// MARK: - Color picker dressed as a tile

private struct ColorPickerTile: View {
    @Binding var color: Color
    let label: String

    @Environment(\.generatorMetrics) private var metrics

    var body: some View {
        ColorPicker("", selection: $color, supportsOpacity: false)
            .labelsHidden()
            .frame(width: metrics.swatch * 0.68, height: metrics.swatch * 0.68)
            .frame(width: metrics.swatch, height: metrics.swatch)
            .background(
                RoundedRectangle(cornerRadius: metrics.swatch * 0.3, style: .continuous)
                    .fill(.white.opacity(0.68))
            )
            .accessibilityLabel(label)
    }
}

// MARK: - Gradient type glyph

private struct GradientTypeGlyph: View {
    let type: GradientConfiguration.GradientType
    let colors: [Color]

    var body: some View {
        switch type {
        case .linear:
            Circle().fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
        case .radial:
            Circle().fill(RadialGradient(colors: colors, center: .center, startRadius: 0, endRadius: 16))
        case .angular:
            Circle().fill(AngularGradient(colors: colors + [colors.first ?? .clear], center: .center))
        case .diamond:
            Rectangle()
                .fill(RadialGradient(colors: colors, center: .center, startRadius: 0, endRadius: 16))
                .rotationEffect(.degrees(45))
                .scaleEffect(0.72)
        }
    }
}

// MARK: - Row that never clips a selection ring

/// Horizontal scroller with enough inner padding that the concentric selection
/// ring — which draws outside its tile — survives the scroll view's clipping.
struct TileRow<Content: View>: View {
    @ViewBuilder var content: () -> Content

    @Environment(\.generatorMetrics) private var metrics

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: metrics.tileGap) {
                content()
            }
            .padding(7)
        }
        .padding(-7)
    }
}

// MARK: - Accessibility names

extension SerializableColor {
    var accessibilityName: String {
        switch self {
        case .black: String(localized: "color.black", defaultValue: "Black")
        case .navy: String(localized: "color.navy", defaultValue: "Navy")
        case .forest: String(localized: "color.forest", defaultValue: "Forest")
        case .burgundy: String(localized: "color.burgundy", defaultValue: "Burgundy")
        case .charcoal: String(localized: "color.charcoal", defaultValue: "Charcoal grey")
        case .indigo: String(localized: "color.indigo", defaultValue: "Indigo")
        default: String(localized: "color.custom", defaultValue: "Custom color")
        }
    }
}

extension GradientConfiguration {
    var accessibilityName: String {
        if matchesStops(of: .purpleViolet) {
            return String(localized: "gradient.purpleViolet", defaultValue: "Purple violet")
        }
        if matchesStops(of: .blueCyan) {
            return String(localized: "gradient.blueCyan", defaultValue: "Blue cyan")
        }
        if matchesStops(of: .orangePink) {
            return String(localized: "gradient.orangePink", defaultValue: "Orange pink")
        }
        return String(localized: "gradient.custom", defaultValue: "Custom gradient")
    }

    /// Two gradients share a swatch when their stops match; type and angle are
    /// separate controls.
    func matchesStops(of other: GradientConfiguration) -> Bool {
        startColor == other.startColor && endColor == other.endColor
    }
}

#Preview("Color group") {
    ZStack {
        GradientBackground()
        ColorGroupView(configuration: .constant(.branded), onLocked: { _ in })
            .padding(24)
    }
    .environmentObject(PurchaseManager.shared)
}
