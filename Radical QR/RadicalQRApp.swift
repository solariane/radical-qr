import SwiftUI
import SwiftData

@main
struct RadicalQRApp: App {
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var deepLinkHandler = DeepLinkHandler.shared

    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    init() {
        #if DEBUG
        // Uncomment to test Pro features during development
        // UserDefaults.standard.set(true, forKey: "debug_force_pro")
        #endif
    }

    private let sharedModelContainer = AppModelContainer.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(purchaseManager)
                .environment(deepLinkHandler)
        }
        .modelContainer(sharedModelContainer)
        .handlesExternalEvents(matching: Set(["*"]))
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1000, height: 900)
        #endif

        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(purchaseManager)
                .modelContainer(sharedModelContainer)
        }
        #endif
    }
}

extension ReviewPrompter {
    /// Three saves or copies, on two different days, at least three days
    /// after the first: someone who came back, not someone trying the app.
    static let shared = ReviewPrompter(rules: Rules(
        minimumMoments: 3,
        minimumActiveDays: 2,
        minimumDaysSinceFirstUse: 3
    ))
}
