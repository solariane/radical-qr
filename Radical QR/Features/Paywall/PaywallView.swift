import SwiftUI
import StoreKit

/// Paywall view for Pro upgrade
struct PaywallView: View {
    let feature: ProFeature?

    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    @State private var isPurchasing = false
    @State private var purchaseError: Error?

    init(feature: ProFeature? = nil) {
        self.feature = feature
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                GradientBackground()

                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        headerSection

                        // Feature highlight (if opened for specific feature)
                        if let feature = feature {
                            featureHighlight(feature)
                        }

                        // All features list
                        featuresSection

                        // Side-by-side comparison with Free tier
                        comparisonSection

                        // Price and purchase button
                        purchaseSection

                        // Restore purchases
                        restoreButton

                        // Legal links
                        legalSection
                    }
                    .padding()
                    .padding(.bottom, 40)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .alert(
                String(localized: "purchase.error.title", defaultValue: "Purchase Failed"),
                isPresented: .init(
                    get: { purchaseError != nil },
                    set: { if !$0 { purchaseError = nil } }
                )
            ) {
                Button(String(localized: "action.ok", defaultValue: "OK")) {
                    purchaseError = nil
                }
            } message: {
                if let error = purchaseError {
                    Text(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Pro badge
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.title)
                Text("PRO")
                    .font(.largeTitle.weight(.bold))
            }
            .foregroundStyle(.white)

            Text(String(localized: "paywall.title", defaultValue: "Unlock Full Power"))
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)

            Text(String(localized: "paywall.subtitle", defaultValue: "One-time purchase. Lifetime access."))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.top, 20)
    }

    // MARK: - Feature Highlight

    private func featureHighlight(_ feature: ProFeature) -> some View {
        VStack(spacing: 12) {
            Image(systemName: feature.iconName)
                .font(.system(size: 40))
                .foregroundStyle(.white)

            Text(feature.displayName)
                .font(.headline)
                .foregroundStyle(.white)

            Text(feature.description)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.white.opacity(0.15))
        )
    }

    // MARK: - Features Section

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "paywall.features.title", defaultValue: "Everything in Pro"))
                .font(.headline)
                .foregroundStyle(.white)

            VStack(spacing: 12) {
                ForEach(ProFeature.allCases, id: \.self) { feature in
                    FeatureRow(feature: feature)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.white.opacity(0.1))
        )
    }

    // MARK: - Comparison Section

    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "paywall.comparison.title", defaultValue: "Free vs Pro"))
                .font(.headline)
                .foregroundStyle(.white)

            FeatureComparisonView()
        }
    }

    // MARK: - Purchase Section

    private var purchaseSection: some View {
        VStack(spacing: 16) {
            // Price
            if let product = purchaseManager.proProduct {
                VStack(spacing: 4) {
                    Text(product.displayPrice)
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.white)

                    Text(String(localized: "paywall.oneTime", defaultValue: "One-time purchase"))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
            } else if purchaseManager.isLoading {
                ProgressView()
                    .tint(.white)
            }

            // Purchase button — deeper, more saturated version of the app's
            // signature gradient + glossy highlight + strong shadow so it
            // visually "lifts" off the lighter page background AND the white
            // comparison table.
            Button {
                Task {
                    await purchase()
                }
            } label: {
                HStack {
                    if isPurchasing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(String(localized: "paywall.purchase", defaultValue: "Get Pro"))
                            .font(.headline.weight(.semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    ZStack {
                        // Rich, saturated diagonal gradient
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.30, green: 0.20, blue: 0.85), // deep indigo
                                        Color(red: 0.55, green: 0.22, blue: 0.75)  // deep violet
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        // Soft top-to-mid highlight → gives the button some depth
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.22),
                                        .white.opacity(0.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    }
                )
                .overlay(
                    // Thin bright border to sharpen the edges
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                )
                .foregroundStyle(.white)
                // Two shadows: a crisp near-shadow + a wider soft glow
                .shadow(color: .black.opacity(0.35), radius: 10, y: 6)
                .shadow(color: .white.opacity(0.15), radius: 24, y: 0)
            }
            .buttonStyle(.plain)
            .disabled(isPurchasing || purchaseManager.proProduct == nil)
        }
    }

    // MARK: - Restore Button

    private var restoreButton: some View {
        Button {
            Task {
                await purchaseManager.restorePurchases()
                if purchaseManager.isPro {
                    dismiss()
                }
            }
        } label: {
            Text(String(localized: "paywall.restore", defaultValue: "Restore Purchases"))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    // MARK: - Legal Section

    /// Website language path based on the user's preferred language
    private var websiteLang: String {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        switch code {
        case "fr": return "fr"
        case "de": return "de"
        case "es": return "es"
        case "it": return "it"
        case "pt": return "pt-br"
        case "ja": return "ja"
        case "ar": return "ar"
        case "hi": return "hi"
        case "zh": return "zh-hans"
        default: return "en"
        }
    }

    private var legalSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Link(
                    String(localized: "paywall.terms", defaultValue: "Terms"),
                    destination: URL(string: "https://radicalsolution.com/\(websiteLang)/radical-qr/legal/")!
                )

                Text("•")

                Link(
                    String(localized: "paywall.privacy", defaultValue: "Privacy"),
                    destination: URL(string: "https://radicalsolution.com/\(websiteLang)/privacy/")!
                )
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.6))
        }
    }

    // MARK: - Actions

    private func purchase() async {
        isPurchasing = true

        do {
            let success = try await purchaseManager.purchasePro()
            if success {
                dismiss()
            }
        } catch {
            purchaseError = error
        }

        isPurchasing = false
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let feature: ProFeature

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)

                Text(feature.description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()
        }
    }
}

// MARK: - Feature Comparison View

struct FeatureComparisonView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(String(localized: "comparison.feature", defaultValue: "Feature"))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(String(localized: "comparison.free", defaultValue: "Free"))
                    .frame(width: 60)

                Text(String(localized: "comparison.pro", defaultValue: "Pro"))
                    .frame(width: 60)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Rows
            VStack(spacing: 0) {
                ComparisonRow(
                    feature: String(localized: "comparison.colors", defaultValue: "Colors"),
                    free: "6",
                    pro: String(localized: "comparison.unlimited", defaultValue: "Unlimited")
                )

                ComparisonRow(
                    feature: String(localized: "comparison.gradients", defaultValue: "Gradients"),
                    free: "3",
                    pro: String(localized: "comparison.unlimited", defaultValue: "Unlimited")
                )

                ComparisonRow(
                    feature: String(localized: "comparison.gradientTypes", defaultValue: "Gradient Types"),
                    free: "2",
                    pro: "4"
                )

                ComparisonRow(
                    feature: String(localized: "comparison.exportSize", defaultValue: "Export Size"),
                    free: "512px",
                    pro: "4096px"
                )

                ComparisonRow(
                    feature: String(localized: "comparison.vectorExport", defaultValue: "PDF & SVG Export"),
                    free: nil,
                    pro: "check"
                )

                ComparisonRow(
                    feature: String(localized: "comparison.logo", defaultValue: "Logo"),
                    free: nil,
                    pro: "check"
                )

                ComparisonRow(
                    feature: String(localized: "comparison.history", defaultValue: "History"),
                    free: nil,
                    pro: "check"
                )

                ComparisonRow(
                    feature: String(localized: "comparison.iCloud", defaultValue: "iCloud Sync"),
                    free: nil,
                    pro: "check"
                )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
        )
    }
}

struct ComparisonRow: View {
    let feature: String
    let free: String?
    let pro: String

    var body: some View {
        HStack {
            Text(feature)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)

            Group {
                if let free = free {
                    Text(free)
                        .font(.caption)
                } else {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 60)

            Group {
                if pro == "check" {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.green)
                } else {
                    Text(pro)
                        .font(.caption)
                }
            }
            .frame(width: 60)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.05))
    }
}

// MARK: - Preview

#Preview("Paywall") {
    PaywallView()
        .environmentObject(PurchaseManager.shared)
}

#Preview("Paywall with Feature") {
    PaywallView(feature: .logoEmbedding)
        .environmentObject(PurchaseManager.shared)
}

#Preview("Feature Comparison") {
    FeatureComparisonView()
        .padding()
}
