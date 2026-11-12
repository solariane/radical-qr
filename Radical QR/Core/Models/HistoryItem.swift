import Foundation
import SwiftData

/// Represents a saved QR code in history (Pro feature).
///
/// All stored properties have defaults so SwiftData can hydrate instances
/// during CloudKit merges without needing a MainActor-isolated init
/// (a CloudKit+SwiftData requirement).
@Model
final class HistoryItem {
    var id: UUID = UUID()
    var content: String = ""
    var dataType: String = DataType.text.rawValue
    var configurationData: Data = Data()
    var createdAt: Date = Date()
    var lastUsedAt: Date = Date()
    var usageCount: Int = 1
    var title: String?

    init(
        content: String = "",
        dataType: DataType = .text,
        configuration: QRCodeConfiguration = .default,
        title: String? = nil
    ) {
        self.id = UUID()
        self.content = content
        self.dataType = dataType.rawValue
        self.configurationData = (try? JSONEncoder().encode(configuration)) ?? Data()
        self.createdAt = Date()
        self.lastUsedAt = Date()
        self.usageCount = 1
        self.title = title
    }

    var parsedDataType: DataType {
        DataType(rawValue: dataType) ?? .text
    }

    /// Gets the decoded configuration.
    func getConfiguration() -> QRCodeConfiguration {
        (try? JSONDecoder().decode(QRCodeConfiguration.self, from: configurationData)) ?? .default
    }

    /// Sets the configuration by encoding it.
    func setConfiguration(_ configuration: QRCodeConfiguration) {
        configurationData = (try? JSONEncoder().encode(configuration)) ?? Data()
    }

    /// Updates the last used timestamp and increments usage count.
    func markUsed() {
        lastUsedAt = Date()
        usageCount += 1
    }

    /// Creates a duplicate of this history item.
    func duplicate() -> HistoryItem {
        HistoryItem(
            content: content,
            dataType: parsedDataType,
            configuration: getConfiguration(),
            title: title.map { "\($0) (Copy)" }
        )
    }
}

// MARK: - Style Preset

/// Saved style configuration (Pro feature).
/// All properties default-initialized so CloudKit can hydrate instances.
@Model
final class StylePreset {
    var id: UUID = UUID()
    var name: String = ""
    var configurationData: Data = Data()
    var createdAt: Date = Date()
    var isDefault: Bool = false

    init(name: String = "", configuration: QRCodeConfiguration = .default, isDefault: Bool = false) {
        self.id = UUID()
        self.name = name
        self.configurationData = (try? JSONEncoder().encode(configuration)) ?? Data()
        self.createdAt = Date()
        self.isDefault = isDefault
    }

    func getConfiguration() -> QRCodeConfiguration {
        (try? JSONDecoder().decode(QRCodeConfiguration.self, from: configurationData)) ?? .default
    }

    func setConfiguration(_ configuration: QRCodeConfiguration) {
        configurationData = (try? JSONEncoder().encode(configuration)) ?? Data()
    }
}

// MARK: - Recording

extension HistoryItem {
    /// Records a code in history. De-duplicates by content: an entry with the
    /// same content gets the new style and a bumped usage count instead of a
    /// twin. Keeps `FeatureLimit.maxHistoryItems` by pruning the oldest.
    /// Used by the generator and by the App Intents.
    @discardableResult
    static func record(
        content: String,
        dataType: DataType,
        configuration: QRCodeConfiguration,
        in context: ModelContext
    ) -> HistoryItem {
        let descriptor = FetchDescriptor<HistoryItem>(
            sortBy: [SortDescriptor(\.lastUsedAt, order: .reverse)]
        )
        let items = (try? context.fetch(descriptor)) ?? []

        if let existing = items.first(where: { $0.content == content }) {
            existing.setConfiguration(configuration)
            existing.markUsed()
            return existing
        }

        let newItem = HistoryItem(content: content, dataType: dataType, configuration: configuration)
        context.insert(newItem)

        // Prune anything beyond the cap (oldest first).
        let overflow = items.count + 1 - FeatureLimit.maxHistoryItems
        if overflow > 0 {
            for item in items.suffix(overflow) {
                context.delete(item)
            }
        }
        return newItem
    }
}

// MARK: - History Query Helpers

extension HistoryItem {
    /// Fetch descriptor for recent items, sorted by last used date
    static var recentDescriptor: FetchDescriptor<HistoryItem> {
        var descriptor = FetchDescriptor<HistoryItem>(
            sortBy: [SortDescriptor(\.lastUsedAt, order: .reverse)]
        )
        descriptor.fetchLimit = FeatureLimit.maxHistoryItems
        return descriptor
    }

    /// Fetch descriptor for most used items
    static var mostUsedDescriptor: FetchDescriptor<HistoryItem> {
        var descriptor = FetchDescriptor<HistoryItem>(
            sortBy: [SortDescriptor(\.usageCount, order: .reverse)]
        )
        descriptor.fetchLimit = 10
        return descriptor
    }
}
