import SwiftUI
import SwiftData

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
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
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
