import SwiftUI

/// The "Background" row of the colour family: white, clear, the logo cutout
/// when there is a logo, and — Pro — any colour.
///
/// Every change goes through `setBackground`, which moves the code to the same
/// swatch of the new palette so it stays readable on the new colour.
struct BackgroundRow: View {
    @Binding var configuration: QRCodeConfiguration
    let onLocked: (ProFeature) -> Void

    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.generatorMetrics) private var metrics

    /// What the picker shows before any colour was chosen: a background dark
    /// enough that opening it already reads as "a colour, not white".
    private static let suggestion = SerializableColor(red: 0.118, green: 0.227, blue: 0.373)

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.labelGap) {
            SettingRowLabel(text: String(localized: "customization.background", defaultValue: "Background"))

            HStack(spacing: metrics.tileGap) {
                ForEach(options, id: \.self) { type in
                    SettingTile(
                        width: metrics.tile,
                        height: metrics.tile,
                        isSelected: configuration.backgroundType == type && configuration.customBackground == nil,
                        label: type.displayName,
                        action: { configuration.setBackground(type) }
                    ) {
                        BackgroundGlyph(type: type)
                    }
                }
                colorTile
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private var colorTile: some View {
        let label = String(
            localized: "background.color",
            defaultValue: "Background color",
            comment: "Pro option: pick any colour for the background of the generated QR code."
        )
        if purchaseManager.isPro {
            ColorPickerTile(
                color: Binding(
                    get: { (configuration.backgroundColor ?? Self.suggestion).color },
                    set: { configuration.setBackground(.white, color: SerializableColor($0)) }
                ),
                label: label,
                size: metrics.tile,
                isSelected: configuration.customBackground != nil
            )
        } else {
            SettingTile(
                width: metrics.tile,
                height: metrics.tile,
                isSelected: false,
                isLocked: true,
                label: label,
                action: { onLocked(.fullColorPicker) }
            ) {
                BackgroundGlyph(type: .white, fill: AngularGradient(colors: Self.wheel, center: .center))
            }
        }
    }

    private var options: [BackgroundType] {
        var options: [BackgroundType] = [.white, .transparent]
        if purchaseManager.isPro && configuration.logoData != nil {
            options.append(.transparentWithLogoCutout)
        }
        return options
    }

    private static let wheel: [Color] = [.red, .yellow, .green, .cyan, .blue, .purple, .red]
}

#Preview("Background row") {
    ZStack {
        GradientBackground()
        BackgroundRow(configuration: .constant(.default), onLocked: { _ in })
            .padding(24)
    }
    .environmentObject(PurchaseManager.shared)
}
