import SwiftUI

/// The single control shape behind every graphic setting in the generator.
///
/// A squircle showing the result of its option; selection is the app icon's
/// concentric ring rather than a tint, and a Pro option dims its glyph and stamps
/// a padlock. The visible label lives only in the accessibility label — that is
/// what lets the rail carry four eye shapes on a 375pt screen without a word.
struct SettingTile<Content: View>: View {
    var width: CGFloat = 56
    var height: CGFloat = 56
    /// Glyph size as a fraction of the tile. Text tiles want nearly the whole box.
    var contentScale: CGFloat = 0.61
    var isSelected: Bool
    var isLocked: Bool = false
    let label: String
    let action: () -> Void
    @ViewBuilder var content: () -> Content

    private var cornerRadius: CGFloat { min(width, height) * 0.3 }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                content()
                    .frame(width: width * contentScale, height: height * contentScale)
                    .opacity(isLocked ? 0.5 : 1)
                    .frame(width: width, height: height)

                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color(white: 0.28))
                        .padding(3)
                        .background(Circle().fill(.white.opacity(0.95)))
                        .padding(3)
                }
            }
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.white.opacity(isSelected ? 1 : 0.68))
            )
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: cornerRadius + 3, style: .continuous)
                        .strokeBorder(.white.opacity(0.95), lineWidth: 3)
                        .padding(-3)
                    RoundedRectangle(cornerRadius: cornerRadius + 5.5, style: .continuous)
                        .strokeBorder(.white.opacity(0.34), lineWidth: 2.5)
                        .padding(-5.5)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .animation(.easeInOut(duration: 0.16), value: isSelected)
    }
}

/// A tile whose content is a short technical token (512, PNG) — an acronym or a
/// number reads the same in every language, so these keep their text.
struct SettingTokenTile: View {
    var isSelected: Bool
    var isLocked: Bool = false
    let token: String
    let label: String
    let action: () -> Void

    var body: some View {
        SettingTile(
            width: 72,
            height: 48,
            contentScale: 0.86,
            isSelected: isSelected,
            isLocked: isLocked,
            label: label,
            action: action
        ) {
            Text(token)
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(QRGlyph.ink)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
    }
}

/// Section label above a row of tiles. One string per row instead of one per
/// option — the whole point of the graphic tiles.
struct SettingRowLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(0.7)
            .textCase(.uppercase)
            .foregroundStyle(.white.opacity(0.72))
    }
}

#Preview("Tiles") {
    ZStack {
        GradientBackground()
        VStack(alignment: .leading, spacing: 16) {
            SettingRowLabel(text: "Modules")
            HStack(spacing: 11) {
                SettingTile(isSelected: false, label: "Sharp", action: {}) {
                    ModuleShapeGlyph(roundness: 0)
                }
                SettingTile(isSelected: true, label: "Rounded", action: {}) {
                    ModuleShapeGlyph(roundness: 0.6)
                }
                SettingTile(isSelected: false, isLocked: true, label: "Dot", action: {}) {
                    EyeShapeGlyph(style: .dot)
                }
            }
            HStack(spacing: 10) {
                SettingTokenTile(isSelected: true, token: "512", label: "512 px", action: {})
                SettingTokenTile(isSelected: false, isLocked: true, token: "2048", label: "2048 px", action: {})
            }
        }
        .padding(30)
    }
}
