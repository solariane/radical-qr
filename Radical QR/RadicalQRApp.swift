import SwiftUI
import SwiftData

@main
struct RadicalQRApp: App {
    @StateObject private var purchaseManager = PurchaseManager.shared

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
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 700)
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
