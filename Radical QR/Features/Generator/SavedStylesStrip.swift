import SwiftUI
import SwiftData

/// The user's own styles, as thumbnails.
///
/// Curated presets would have been a second set of choices to learn; this instead
/// hands back what the user already built — one tap saves the current look, one
/// tap restores it. Free users see the strip with a locked slot, which is what
/// makes the Pro pitch concrete instead of abstract.
struct SavedStylesStrip: View {
    @Binding var configuration: QRCodeConfiguration
    let onLocked: () -> Void

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Query(sort: \StylePreset.createdAt, order: .forward) private var presets: [StylePreset]

    private var isFull: Bool { presets.count >= FeatureLimit.maxStylePresets }

    /// The saved style matching what is on screen right now, if any.
    private func isCurrent(_ preset: StylePreset) -> Bool {
        var saved = preset.getConfiguration()
        var current = configuration
        // A logo belongs to one code, not to a style — ignore it when matching.
        saved.logoData = nil
        current.logoData = nil
        return saved == current
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            SettingRowLabel(text: String(localized: "styles.mine", defaultValue: "My styles"))

            HStack(spacing: 11) {
                ForEach(presets) { preset in
                    SettingTile(
                        width: 44,
                        height: 44,
                        contentScale: 0.74,
                        isSelected: isCurrent(preset),
                        label: preset.name,
                        action: { configuration = preset.getConfiguration() }
                    ) {
                        MiniQRGlyph(configuration: preset.getConfiguration())
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            modelContext.delete(preset)
                        } label: {
                            Label(
                                String(localized: "styles.delete", defaultValue: "Delete style"),
                                systemImage: "trash"
                            )
                        }
                    }
                }

                if !isFull {
                    SettingTile(
                        width: 44,
                        height: 44,
                        contentScale: 0.42,
                        isSelected: false,
                        isLocked: !purchaseManager.isPro,
                        label: String(localized: "styles.save", defaultValue: "Save this style"),
                        action: saveCurrent
                    ) {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(QRGlyph.ink.opacity(0.65))
                    }
                }

                // With no styles yet the row is a lone "+"; say what it is for.
                if presets.isEmpty {
                    Text(String(
                        localized: "styles.hint",
                        defaultValue: "Save the look you built — one tap brings it back."
                    ))
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private func saveCurrent() {
        guard purchaseManager.isPro else {
            onLocked()
            return
        }
        guard !isFull else { return }

        var stored = configuration
        stored.logoData = nil

        // Settings still shows a single "current" preset, so the newest one keeps
        // that flag and the others give it up.
        for preset in presets where preset.isDefault {
            preset.isDefault = false
        }

        let preset = StylePreset(
            name: String(localized: "styles.autoName", defaultValue: "Style \(presets.count + 1)"),
            configuration: stored,
            isDefault: true
        )
        modelContext.insert(preset)
    }
}

#Preview("Saved styles") {
    ZStack {
        GradientBackground()
        SavedStylesStrip(configuration: .constant(.branded), onLocked: {})
            .padding(30)
    }
    .environmentObject(PurchaseManager.shared)
    .modelContainer(for: StylePreset.self, inMemory: true)
}
