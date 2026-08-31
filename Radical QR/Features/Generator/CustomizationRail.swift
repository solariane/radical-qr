import SwiftUI
import SwiftData

/// The generator's settings, as four families behind an icon rail.
///
/// Only one family is on screen at a time, which is what lets the whole generator
/// — preview, settings and the save button — fit an iPhone SE without scrolling.
/// The rail marks the active family with the app icon's concentric ring rather
/// than a tinted pill.
struct CustomizationRail: View {
    enum Family: String, CaseIterable, Identifiable {
        case styles, color, shape, brand, export

        var id: String { rawValue }

        /// Spoken name; the rail itself never shows text.
        var label: String {
            switch self {
            case .styles: String(localized: "family.styles", defaultValue: "My styles")
            case .color: String(localized: "family.color", defaultValue: "Color")
            case .shape: String(localized: "family.shape", defaultValue: "Shape")
            case .brand: String(localized: "family.brand", defaultValue: "Logo and caption")
            case .export: String(localized: "family.export", defaultValue: "Export")
            }
        }

        var symbol: String? {
            switch self {
            case .styles: "star"
            case .color: "paintpalette"
            case .shape: nil // drawn below — no symbol says "module corners"
            case .brand: "photo"
            case .export: "square.and.arrow.down"
            }
        }
    }

    @Binding var configuration: QRCodeConfiguration
    @Binding var family: Family
    @Binding var exportSize: ExportSize
    @Binding var exportFormat: ExportFormat
    let autoCaption: String
    let onLocked: (ProFeature) -> Void

    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.generatorMetrics) private var metrics

    /// Icon color on an active (white) rail button.
    private static let activeInk = Color(red: 0.357, green: 0.271, blue: 0.659)

    var body: some View {
        VStack(spacing: metrics.sectionGap) {
            familyRail

            activeGroup
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(metrics.panelPadding)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.white.opacity(0.15))
                )
                // The panel is always light-on-violet, so nested system controls
                // must resolve .secondary and placeholders against a light scheme
                // even when the app is in dark mode.
                .environment(\.colorScheme, .light)
        }
    }

    @ViewBuilder
    private var activeGroup: some View {
        switch family {
        case .styles:
            SavedStylesStrip(configuration: $configuration, onLocked: { onLocked(.stylePreset) })
        case .color:
            ColorGroupView(configuration: $configuration, onLocked: onLocked)
        case .shape:
            ShapeGroupView(configuration: $configuration, onLocked: onLocked)
        case .brand:
            BrandGroupView(configuration: $configuration, autoCaption: autoCaption, onLocked: onLocked)
        case .export:
            exportGroup
        }
    }

    // MARK: - Family rail

    private var familyRail: some View {
        HStack(spacing: metrics.tileGap - 1) {
            ForEach(Family.allCases) { item in
                let active = family == item
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { family = item }
                } label: {
                    Group {
                        if let symbol = item.symbol {
                            Image(systemName: symbol)
                                .font(.system(size: 18, weight: .medium))
                        } else {
                            ModuleMixGlyph(color: active ? Self.activeInk : .white)
                                .frame(width: 20, height: 20)
                        }
                    }
                    .foregroundStyle(active ? Self.activeInk : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: metrics.railHeight)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.white.opacity(active ? 1 : 0.18))
                    )
                    .overlay {
                        if active {
                            RoundedRectangle(cornerRadius: 19, style: .continuous)
                                .strokeBorder(.white.opacity(0.9), lineWidth: 3)
                                .padding(-3)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.label)
                .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    // MARK: - Export

    private var exportGroup: some View {
        VStack(alignment: .leading, spacing: metrics.rowGap) {
            VStack(alignment: .leading, spacing: metrics.labelGap) {
                SettingRowLabel(text: String(localized: "export.size", defaultValue: "Size"))

                TileRow {
                    ForEach(ExportSize.allSizes, id: \.width) { size in
                        let locked = !purchaseManager.isExportSizeAvailable(size)
                        SettingTokenTile(
                            isSelected: exportSize == size,
                            isLocked: locked,
                            token: "\(size.width)",
                            label: size.displayName
                        ) {
                            if locked {
                                onLocked(.unlimitedExportSize)
                            } else {
                                exportSize = size
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: metrics.labelGap) {
                SettingRowLabel(text: String(localized: "export.format", defaultValue: "Format"))

                TileRow {
                    ForEach(ExportFormat.allCases) { format in
                        let locked = format.requiresPro && !purchaseManager.isPro
                        SettingTokenTile(
                            isSelected: exportFormat == format,
                            isLocked: locked,
                            token: format.displayName,
                            label: format.displayName
                        ) {
                            if locked {
                                onLocked(.vectorExport)
                            } else {
                                exportFormat = format
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Rail icon for the shape family

/// Two square modules and two round ones — the choice the family contains, drawn
/// rather than named.
struct ModuleMixGlyph: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let cell = size.width / 2
            let inset = cell * 0.11
            let corners: [CGFloat] = [0.5, 0.16, 0.16, 0.5]
            for (index, fraction) in corners.enumerated() {
                let rect = CGRect(
                    x: CGFloat(index % 2) * cell + inset,
                    y: CGFloat(index / 2) * cell + inset,
                    width: cell - inset * 2,
                    height: cell - inset * 2
                )
                context.fill(
                    Path(roundedRect: rect, cornerRadius: rect.width * fraction),
                    with: .color(color)
                )
            }
        }
    }
}

#Preview("Rail") {
    ZStack {
        GradientBackground()
        CustomizationRail(
            configuration: .constant(.branded),
            family: .constant(.shape),
            exportSize: .constant(.medium),
            exportFormat: .constant(.png),
            autoCaption: "radicalsolution.com",
            onLocked: { _ in }
        )
        .padding(20)
    }
    .environmentObject(PurchaseManager.shared)
    .modelContainer(for: StylePreset.self, inMemory: true)
}
