import SwiftUI

/// The system colour picker dressed as a tile, so a Pro "any colour" option
/// sits in a row of `SettingTile`s as one vocabulary. The well shows the colour
/// itself; `isSelected` draws the same concentric ring as `SettingTile`.
struct ColorPickerTile: View {
    @Binding var color: Color
    let label: String
    /// Side of the tile; the colour-swatch size when nil.
    var size: CGFloat?
    var isSelected = false

    @Environment(\.generatorMetrics) private var metrics

    private var side: CGFloat { size ?? metrics.swatch }
    private var cornerRadius: CGFloat { side * 0.3 }

    var body: some View {
        ColorPicker("", selection: $color, supportsOpacity: false)
            .labelsHidden()
            .frame(width: side * 0.68, height: side * 0.68)
            .frame(width: side, height: side)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.white.opacity(isSelected ? 1 : 0.68))
            )
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: cornerRadius + 3, style: .continuous)
                        .strokeBorder(.white.opacity(0.95), lineWidth: 3)
                        .padding(-3)
                        .allowsHitTesting(false)
                    RoundedRectangle(cornerRadius: cornerRadius + 5.5, style: .continuous)
                        .strokeBorder(.white.opacity(0.34), lineWidth: 2.5)
                        .padding(-5.5)
                        .allowsHitTesting(false)
                }
            }
            .accessibilityLabel(label)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .animation(.easeInOut(duration: 0.16), value: isSelected)
    }
}

#Preview("Color picker tile") {
    ZStack {
        GradientBackground()
        HStack(spacing: 14) {
            ColorPickerTile(color: .constant(.indigo), label: "Custom color")
            ColorPickerTile(color: .constant(.teal), label: "Background color", size: 56, isSelected: true)
        }
    }
}
