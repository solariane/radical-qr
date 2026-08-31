import SwiftUI

/// Brand family of the customization rail: the centered logo and the caption
/// printed under the code — the two things that turn a QR code into someone's QR
/// code. Caption on/off is two tiles rather than a switch, so it matches the rest
/// of the rail and shows what it does.
struct BrandGroupView: View {
    @Binding var configuration: QRCodeConfiguration
    /// Caption the generator would produce on its own — used as the field's
    /// placeholder so an empty field is not a mystery.
    let autoCaption: String
    let onLocked: (ProFeature) -> Void

    @EnvironmentObject private var purchaseManager: PurchaseManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            logoRow
            captionRow
        }
    }

    // MARK: - Logo

    private var logoRow: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                SettingRowLabel(text: String(localized: "logo.title", defaultValue: "Logo"))
                if !purchaseManager.isPro {
                    ProBadge()
                }
                Spacer()
                if purchaseManager.isPro && configuration.logoData != nil {
                    Button {
                        withAnimation { configuration.logoData = nil }
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(.white.opacity(0.18)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "logo.remove", defaultValue: "Remove logo"))
                }
            }

            if purchaseManager.isPro {
                CompactLogoDropZone(logoData: $configuration.logoData)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .fill(.white.opacity(0.9))
                    )
            } else {
                Button {
                    onLocked(.logoEmbedding)
                } label: {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(.white.opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                            .frame(width: 68, height: 68)
                            .overlay {
                                Image(systemName: "plus")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.85))
                            }

                        Text(String(localized: "logo.hint", defaultValue: "Drop an image — the clear margin around it is handled for you."))
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.88))
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Caption

    private var captionRow: some View {
        VStack(alignment: .leading, spacing: 5) {
            SettingRowLabel(text: String(localized: "caption.title", defaultValue: "Caption"))

            HStack(spacing: 11) {
                SettingTile(
                    isSelected: !configuration.showCaption,
                    label: String(localized: "caption.off", defaultValue: "No caption"),
                    action: { withAnimation { configuration.showCaption = false } }
                ) {
                    CaptionGlyph(isOn: false)
                }
                SettingTile(
                    isSelected: configuration.showCaption,
                    label: String(localized: "caption.on", defaultValue: "With caption"),
                    action: { withAnimation { configuration.showCaption = true } }
                ) {
                    CaptionGlyph(isOn: true)
                }
                Spacer(minLength: 0)
            }

            if configuration.showCaption {
                captionDetails
            }
        }
    }

    private var captionDetails: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(
                autoCaption,
                text: Binding(
                    get: { configuration.captionText ?? "" },
                    set: { configuration.captionText = $0.isEmpty ? nil : $0 }
                )
            )
            .textFieldStyle(.plain)
            .font(.footnote)
            .foregroundStyle(QRGlyph.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(.white.opacity(0.9))
            )
            .accessibilityLabel(String(localized: "caption.text", defaultValue: "Caption text"))

            HStack(spacing: 11) {
                ForEach(QRCodeConfiguration.CaptionSize.allCases, id: \.self) { size in
                    SettingTile(
                        width: 52,
                        height: 44,
                        contentScale: 0.8,
                        isSelected: configuration.captionSize == size,
                        label: size.displayName,
                        action: { configuration.captionSize = size }
                    ) {
                        // The sample line grows with the option it stands for.
                        Text("Aa")
                            .font(.system(size: captionSampleSize(size), weight: .semibold))
                            .foregroundStyle(QRGlyph.ink)
                    }
                }

                SettingTile(
                    width: 52,
                    height: 44,
                    contentScale: 0.72,
                    isSelected: configuration.captionFitToWidth,
                    label: String(localized: "caption.fitToWidth", defaultValue: "Fit to width"),
                    action: { configuration.captionFitToWidth.toggle() }
                ) {
                    Image(systemName: "arrow.left.and.right.text.horizontal")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(QRGlyph.ink)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private func captionSampleSize(_ size: QRCodeConfiguration.CaptionSize) -> CGFloat {
        switch size {
        case .small: 11
        case .medium: 14
        case .large: 17
        }
    }
}

#Preview("Brand group") {
    ZStack {
        GradientBackground()
        BrandGroupView(
            configuration: .constant(.default),
            autoCaption: "radicalsolution.com",
            onLocked: { _ in }
        )
        .padding(24)
    }
    .environmentObject(PurchaseManager.shared)
}
