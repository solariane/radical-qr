import StoreKit
import SwiftUI
import Combine

/// Manages in-app purchases using StoreKit 2
final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    // Product identifiers
    static let proProductID = "com.radicalsolution.radicalqr.pro"

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?

    private var transactionListener: Task<Void, Error>?

    #if DEBUG
    /// Debug-only override to test Free / Pro states without a real purchase.
    /// Compiled out entirely in Release builds — cannot reach the App Store.
    enum DebugProOverride: String, CaseIterable, Identifiable {
        case auto       // Use the real StoreKit entitlement state
        case forcePro   // Pretend Pro is unlocked
        case forceFree  // Pretend Pro is NOT unlocked

        var id: String { rawValue }

        var label: String {
            switch self {
            case .auto: "Auto (StoreKit)"
            case .forcePro: "Force Pro"
            case .forceFree: "Force Free"
            }
        }
    }

    /// Persisted across launches via UserDefaults; `@Published` so SwiftUI
    /// views observing the manager re-render the instant it changes.
    @Published var debugProOverride: DebugProOverride = .init(
        rawValue: UserDefaults.standard.string(forKey: "debug_pro_override") ?? ""
    ) ?? .auto {
        didSet {
            UserDefaults.standard.set(debugProOverride.rawValue, forKey: "debug_pro_override")
        }
    }
    #endif

    /// Whether the user has Pro access
    var isPro: Bool {
        #if DEBUG
        switch debugProOverride {
        case .forcePro: return true
        case .forceFree: return false
        case .auto: break
        }
        #endif
        return purchasedProductIDs.contains(Self.proProductID)
    }

    /// The Pro product if available
    var proProduct: Product? {
        products.first { $0.id == Self.proProductID }
    }

    private init() {
        transactionListener = listenForTransactions()
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Product Loading

    func loadProducts() async {
        isLoading = true
        error = nil

        do {
            products = try await Product.products(for: [Self.proProductID])
        } catch {
            self.error = error
        }

        isLoading = false
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws -> StoreKit.Transaction? {
        isLoading = true
        error = nil

        defer { isLoading = false }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updatePurchasedProducts()
            await transaction.finish()
            return transaction

        case .userCancelled:
            return nil

        case .pending:
            return nil

        @unknown default:
            return nil
        }
    }

    /// Purchases the Pro product
    func purchasePro() async throws -> Bool {
        guard let product = proProduct else {
            throw PurchaseError.productNotFound
        }

        let transaction = try await purchase(product)
        return transaction != nil
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        isLoading = true
        error = nil

        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            self.error = error
        }
    }

    // MARK: - Transaction Handling

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                do {
                    let transaction = try await self?.checkVerified(result)
                    await self?.updatePurchasedProducts()
                    await transaction?.finish()
                } catch {
                    // Transaction verification failed
                }
            }
        }
    }

    private func updatePurchasedProducts() async {
        var purchased: Set<String> = []

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                switch transaction.productType {
                case .nonConsumable, .autoRenewable:
                    if transaction.revocationDate == nil {
                        purchased.insert(transaction.productID)
                    }
                default:
                    break
                }
            } catch {
                // Transaction verification failed
            }
        }

        self.purchasedProductIDs = purchased
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PurchaseError.verificationFailed
        case .verified(let item):
            return item
        }
    }
}

// MARK: - Purchase Errors

enum PurchaseError: LocalizedError {
    case productNotFound
    case verificationFailed
    case purchaseFailed

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            String(localized: "purchase.error.productNotFound", defaultValue: "Product not found")
        case .verificationFailed:
            String(localized: "purchase.error.verificationFailed", defaultValue: "Purchase verification failed")
        case .purchaseFailed:
            String(localized: "purchase.error.purchaseFailed", defaultValue: "Purchase failed")
        }
    }
}

// MARK: - Feature Gating

extension PurchaseManager {
    /// Checks if a feature is available for the current subscription level
    func isFeatureAvailable(_ feature: ProFeature) -> Bool {
        if isPro { return true }
        return feature.isAvailableInFree
    }

    /// Returns the appropriate limit for a feature based on subscription
    func exportSizeLimit() -> Int {
        isPro ? FeatureLimit.proMaxExportSize : FeatureLimit.freeMaxExportSize
    }

    /// Checks if the given export format is available
    func isExportFormatAvailable(_ format: ExportFormat) -> Bool {
        if isPro { return true }
        return !format.requiresPro
    }

    /// Checks if the given export size is available
    func isExportSizeAvailable(_ size: ExportSize) -> Bool {
        size.width <= exportSizeLimit()
    }
}

// MARK: - Pro Features

enum ProFeature: CaseIterable {
    // Order matters — drives the display order in the paywall features list.
    // Most visually tangible / marketing-heavy features first.
    case vectorExport
    case logoEmbedding
    case unlimitedExportSize
    case history
    case fullColorPicker
    case allGradientTypes
    case eyeStyles
    case stylePreset
    case duplication

    var displayName: String {
        switch self {
        case .eyeStyles:
            String(localized: "feature.eyeStyles", defaultValue: "Eye Styles")
        case .fullColorPicker:
            String(localized: "feature.fullColorPicker", defaultValue: "Full Color Picker")
        case .allGradientTypes:
            String(localized: "feature.allGradientTypes", defaultValue: "All Gradient Types")
        case .vectorExport:
            String(localized: "feature.vectorExport", defaultValue: "Vector Export")
        case .unlimitedExportSize:
            String(localized: "feature.unlimitedExportSize", defaultValue: "Unlimited Export Size")
        case .logoEmbedding:
            String(localized: "feature.logoEmbedding", defaultValue: "Logo Embedding")
        case .history:
            String(localized: "feature.history", defaultValue: "History")
        case .stylePreset:
            String(localized: "feature.stylePreset", defaultValue: "Style Preset")
        case .duplication:
            String(localized: "feature.duplication", defaultValue: "Duplication")
        }
    }

    var description: String {
        switch self {
        case .eyeStyles:
            String(localized: "feature.eyeStyles.description", defaultValue: "Shape the finder patterns — dot and leaf eyes")
        case .fullColorPicker:
            String(localized: "feature.fullColorPicker.description", defaultValue: "Choose any color for your QR codes")
        case .allGradientTypes:
            String(localized: "feature.allGradientTypes.description", defaultValue: "Linear, radial, angular, and diamond gradients")
        case .vectorExport:
            String(localized: "feature.vectorExport.description", defaultValue: "Export PDF & SVG vector graphics for perfect scaling")
        case .unlimitedExportSize:
            String(localized: "feature.unlimitedExportSize.description", defaultValue: "Export up to 4096×4096 pixels")
        case .logoEmbedding:
            String(localized: "feature.logoEmbedding.description", defaultValue: "Add your logo to the center of QR codes")
        case .history:
            String(localized: "feature.history.description", defaultValue: "Access your recent QR codes with iCloud sync")
        case .stylePreset:
            String(localized: "feature.stylePreset.description", defaultValue: "Save your favorite style for quick access")
        case .duplication:
            String(localized: "feature.duplication.description", defaultValue: "Duplicate QR codes from history")
        }
    }

    var iconName: String {
        switch self {
        case .eyeStyles: "viewfinder"
        case .fullColorPicker: "paintpalette"
        case .allGradientTypes: "square.stack.3d.up"
        case .vectorExport: "square.and.arrow.up"
        case .unlimitedExportSize: "arrow.up.left.and.arrow.down.right"
        case .logoEmbedding: "photo"
        case .history: "clock.arrow.circlepath"
        case .stylePreset: "star"
        case .duplication: "doc.on.doc"
        }
    }

    var isAvailableInFree: Bool {
        false
    }
}
