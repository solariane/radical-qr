import Foundation
import SwiftData

/// Represents a saved QR code in history (Pro feature)
@Model
final class HistoryItem {
    var id: UUID
    var content: String
    var dataType: String
    var configurationData: Data
    var createdAt: Date
    var lastUsedAt: Date
    var usageCount: Int
    var title: String?

    @MainActor
    init(
        content: String,
        dataType: DataType,
        configuration: QRCodeConfiguration,
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

    /// Gets the decoded configuration (must be called from MainActor)
    @MainActor
    func getConfiguration() -> QRCodeConfiguration {
        (try? JSONDecoder().decode(QRCodeConfiguration.self, from: configurationData)) ?? .default
    }

    /// Sets the configuration by encoding it (must be called from MainActor)
    @MainActor
    func setConfiguration(_ configuration: QRCodeConfiguration) {
        configurationData = (try? JSONEncoder().encode(configuration)) ?? Data()
    }

    /// Updates the last used timestamp and increments usage count
    func markUsed() {
        lastUsedAt = Date()
        usageCount += 1
    }

    /// Creates a duplicate of this history item
    @MainActor func duplicate() -> HistoryItem {
        HistoryItem(
            content: content,
            dataType: parsedDataType,
            configuration: getConfiguration(),
            title: title.map { "\($0) (Copy)" }
        )
    }
}

// MARK: - Style Preset

/// Saved style configuration (Pro feature)
@Model
final class StylePreset {
    var id: UUID
    var name: String
    var configurationData: Data
    var createdAt: Date
    var isDefault: Bool

    @MainActor
    init(name: String, configuration: QRCodeConfiguration, isDefault: Bool = false) {
        self.id = UUID()
        self.name = name
        self.configurationData = (try? JSONEncoder().encode(configuration)) ?? Data()
        self.createdAt = Date()
        self.isDefault = isDefault
    }

    /// Gets the decoded configuration (must be called from MainActor)
    @MainActor
    func getConfiguration() -> QRCodeConfiguration {
        (try? JSONDecoder().decode(QRCodeConfiguration.self, from: configurationData)) ?? .default
    }

    /// Sets the configuration by encoding it (must be called from MainActor)
    @MainActor
    func setConfiguration(_ configuration: QRCodeConfiguration) {
        configurationData = (try? JSONEncoder().encode(configuration)) ?? Data()
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
