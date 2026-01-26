import SwiftUI
import SwiftData

/// Settings and preferences view
struct SettingsView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    @AppStorage("defaultRoundness") private var defaultRoundness: Double = 0
    @AppStorage("defaultBackgroundTransparent") private var defaultBackgroundTransparent = false

    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            List {
                // Subscription section
                subscriptionSection

                // Default style section
                defaultStyleSection

                // Style preset section (Pro)
                if purchaseManager.isPro {
                    stylePresetSection
                }

                // About section
                aboutSection
            }
            .navigationTitle(String(localized: "settings.title", defaultValue: "Settings"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.done", defaultValue: "Done")) {
                        dismiss()
                    }
                }
            }
            #endif
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(feature: .stylePreset)
        }
    }

    // MARK: - Subscription Section

    private var subscriptionSection: some View {
        Section {
            if purchaseManager.isPro {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "settings.pro.active", defaultValue: "QR Code Pro"))
                            .font(.headline)

                        Text(String(localized: "settings.pro.activeDescription", defaultValue: "All features unlocked"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Button {
                    showPaywall = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "settings.pro.upgrade", defaultValue: "Upgrade to Pro"))
                                .font(.headline)

                            Text(String(localized: "settings.pro.upgradeDescription", defaultValue: "Unlock all features"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    Task {
                        await purchaseManager.restorePurchases()
                    }
                } label: {
                    Text(String(localized: "settings.restore", defaultValue: "Restore Purchases"))
                }
            }
        } header: {
            Text(String(localized: "settings.section.subscription", defaultValue: "Subscription"))
        }
    }

    // MARK: - Default Style Section

    private var defaultStyleSection: some View {
        Section {
            // Default roundness
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(String(localized: "settings.defaultRoundness", defaultValue: "Default Roundness"))

                    Spacer()

                    Text("\(Int(defaultRoundness * 100))%")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Slider(value: $defaultRoundness, in: 0...1)
            }

            // Default background
            Toggle(
                String(localized: "settings.transparentBackground", defaultValue: "Transparent Background"),
                isOn: $defaultBackgroundTransparent
            )
        } header: {
            Text(String(localized: "settings.section.defaults", defaultValue: "Defaults"))
        } footer: {
            Text(String(localized: "settings.defaults.footer", defaultValue: "These settings apply to new QR codes"))
        }
    }

    // MARK: - Style Preset Section

    private var stylePresetSection: some View {
        Section {
            NavigationLink {
                StylePresetView()
            } label: {
                HStack {
                    Image(systemName: "star")
                    Text(String(localized: "settings.stylePreset", defaultValue: "Saved Style"))
                }
            }
        } header: {
            Text(String(localized: "settings.section.style", defaultValue: "Style"))
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            // Version
            HStack {
                Text(String(localized: "settings.version", defaultValue: "Version"))
                Spacer()
                Text(Bundle.main.appVersion)
                    .foregroundStyle(.secondary)
            }

            // Privacy
            Link(destination: URL(string: "https://radicalsolution.com/privacy")!) {
                HStack {
                    Text(String(localized: "settings.privacy", defaultValue: "Privacy Policy"))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Terms
            Link(destination: URL(string: "https://radicalsolution.com/terms")!) {
                HStack {
                    Text(String(localized: "settings.terms", defaultValue: "Terms of Service"))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(String(localized: "settings.section.about", defaultValue: "About"))
        }
    }
}

// MARK: - Style Preset View

struct StylePresetView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var presets: [StylePreset]

    @State private var configuration = QRCodeConfiguration.default
    @State private var presetName = ""
    @State private var showSaveConfirmation = false

    private var currentPreset: StylePreset? {
        presets.first { $0.isDefault }
    }

    var body: some View {
        List {
            // Current preset
            Section {
                if let preset = currentPreset {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(preset.name)
                                .font(.headline)

                            Spacer()

                            StylePreviewBadge(configuration: preset.getConfiguration())
                        }

                        Text(String(localized: "stylePreset.saved", defaultValue: "Saved \(preset.createdAt.formatted(date: .abbreviated, time: .shortened))"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button(role: .destructive) {
                        if let preset = currentPreset {
                            modelContext.delete(preset)
                        }
                    } label: {
                        Label(
                            String(localized: "stylePreset.delete", defaultValue: "Delete Preset"),
                            systemImage: "trash"
                        )
                    }
                } else {
                    Text(String(localized: "stylePreset.empty", defaultValue: "No preset saved"))
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(String(localized: "stylePreset.current", defaultValue: "Current Preset"))
            }

            // Save new preset
            Section {
                TextField(
                    String(localized: "stylePreset.name", defaultValue: "Preset name"),
                    text: $presetName
                )

                NavigationLink {
                    CustomizationPanel(configuration: $configuration)
                } label: {
                    HStack {
                        Text(String(localized: "stylePreset.customize", defaultValue: "Customize Style"))

                        Spacer()

                        StylePreviewBadge(configuration: configuration)
                    }
                }

                Button {
                    savePreset()
                } label: {
                    Label(
                        String(localized: "stylePreset.save", defaultValue: "Save as Preset"),
                        systemImage: "star"
                    )
                }
                .disabled(presetName.isEmpty)
            } header: {
                Text(String(localized: "stylePreset.new", defaultValue: "New Preset"))
            }
        }
        .navigationTitle(String(localized: "stylePreset.title", defaultValue: "Style Preset"))
        .onAppear {
            if let preset = currentPreset {
                configuration = preset.getConfiguration()
                presetName = preset.name
            }
        }
        .alert(
            String(localized: "stylePreset.saved.title", defaultValue: "Preset Saved"),
            isPresented: $showSaveConfirmation
        ) {
            Button(String(localized: "action.ok", defaultValue: "OK")) {}
        }
    }

    private func savePreset() {
        // Remove existing default preset
        for preset in presets where preset.isDefault {
            modelContext.delete(preset)
        }

        // Create new preset
        let newPreset = StylePreset(
            name: presetName,
            configuration: configuration,
            isDefault: true
        )
        modelContext.insert(newPreset)

        showSaveConfirmation = true
    }
}

// MARK: - Style Preview Badge

struct StylePreviewBadge: View {
    let configuration: QRCodeConfiguration
    
    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(previewFill)
            .frame(width: 40, height: 40)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(.secondary.opacity(0.3), lineWidth: 1)
            )
    }
    
    private var previewFill: AnyShapeStyle {
        switch configuration.foregroundStyle {
        case .solid(let color):
            AnyShapeStyle(color.color)
        case .gradient(let gradientConfig):
            AnyShapeStyle(LinearGradient(
                colors: [gradientConfig.startColor.color, gradientConfig.endColor.color],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        }
    }
}

// MARK: - Bundle Extension

extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(PurchaseManager.shared)
}
