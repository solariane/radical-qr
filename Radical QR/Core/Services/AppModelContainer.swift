import Foundation
import SwiftData
import OSLog

/// The one SwiftData container of the app: the windows and the App Intents
/// (Shortcuts, Siri, Spotlight) read the same history and saved styles. Two
/// containers on the same CloudKit store in one process would fight over it.
enum AppModelContainer {
    static let shared: ModelContainer = {
        let schema = Schema([
            HistoryItem.self,
            StylePreset.self
        ])
        let log = Logger(subsystem: "radicalsolution.com.Radical-QR", category: "ModelContainer")

        // Unit tests run inside the app: they must not write into the
        // developer's own history, nor sync it to their iCloud.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil,
           let container = try? ModelContainer(
               for: schema,
               configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
           ) {
            return container
        }

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
}
