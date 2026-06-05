import SwiftUI
import SwiftData
import OSLog

@main
struct RadicalQRApp: App {
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var deepLinkHandler = DeepLinkHandler()

    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    init() {
        #if DEBUG
        // Uncomment to test Pro features during development
        // UserDefaults.standard.set(true, forKey: "debug_force_pro")
        #endif
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            HistoryItem.self,
            StylePreset.self
        ])
        let log = Logger(subsystem: "radicalsolution.com.Radical-QR", category: "ModelContainer")

        // 1. Preferred: private CloudKit database so Pro history + style presets
        // sync across the user's devices. Requires the iCloud capability (+
        // CloudKit service) with the container
        // `iCloud.radicalsolution.com.Radical-QR` in Signing & Capabilities.
        let cloudConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.radicalsolution.com.Radical-QR")
        )
        if let container = try? ModelContainer(for: schema, configurations: [cloudConfiguration]) {
            return container
        }
        // CloudKit can be unavailable (no iCloud account, unsigned build, test
        // host, provisioning hiccup). Degrade gracefully instead of crashing.
        log.warning("CloudKit ModelContainer unavailable; using a local store without iCloud sync.")

        // 2. Fallback: local on-disk store (data persists, just no sync).
        let localConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        if let container = try? ModelContainer(for: schema, configurations: [localConfiguration]) {
            return container
        }
        log.error("Local ModelContainer unavailable; using an in-memory store (history will not persist).")

        // 3. Last resort: in-memory so the app still launches.
        let memoryConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [memoryConfiguration])
        } catch {
            fatalError("Could not create any ModelContainer: \(error)")
        }
    }()

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
