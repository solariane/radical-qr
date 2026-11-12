import AppIntents
import SwiftData

// The things Siri and Shortcuts can name: a saved style ("in my Restaurant
// style") and a code from history ("the Wi-Fi code from last week"). Both are
// few — four styles, a hundred codes — so the queries simply list them all,
// which is the fallback Siri uses for entities that are not in Spotlight.

// MARK: - Saved style

nonisolated struct SavedStyleEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("intent.style.type", defaultValue: "Saved Style")
    )
    static let defaultQuery = SavedStyleQuery()

    let id: UUID
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", image: .init(systemName: "paintpalette"))
    }
}

nonisolated struct SavedStyleQuery: EnumerableEntityQuery {
    @MainActor
    func allEntities() async throws -> [SavedStyleEntity] {
        try Self.presets().map { SavedStyleEntity(id: $0.id, name: $0.name) }
    }

    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [SavedStyleEntity] {
        try await allEntities().filter { identifiers.contains($0.id) }
    }

    @MainActor
    func suggestedEntities() async throws -> [SavedStyleEntity] {
        try await allEntities()
    }

    @MainActor
    static func presets() throws -> [StylePreset] {
        let descriptor = FetchDescriptor<StylePreset>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        return try AppModelContainer.shared.mainContext.fetch(descriptor)
    }

    @MainActor
    static func preset(id: UUID) throws -> StylePreset? {
        try presets().first { $0.id == id }
    }
}

// MARK: - Code from history

struct QRCodeEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("intent.code.type", defaultValue: "QR Code"),
        numericFormat: LocalizedStringResource("intent.code.count", defaultValue: "\(placeholder: .int) QR codes")
    )
    static let defaultQuery = QRCodeEntityQuery()

    let id: UUID

    /// What the code holds, as encoded: a link, a Wi-Fi string, a vCard.
    @Property(title: LocalizedStringResource("intent.code.content", defaultValue: "Content"))
    var content: String

    /// "Link", "Wi-Fi", "Contact"… in the user's language.
    @Property(title: LocalizedStringResource("intent.code.kind", defaultValue: "Kind"))
    var kind: String

    @Property(title: LocalizedStringResource("intent.code.lastUsed", defaultValue: "Last Used"))
    var lastUsedAt: Date

    let summary: String
    let iconName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(summary)",
            subtitle: "\(kind)",
            image: .init(systemName: iconName)
        )
    }

    @MainActor
    init(_ item: HistoryItem) {
        id = item.id
        let input = QRInput(content: item.content, detectedType: item.parsedDataType)
        summary = item.title ?? QRIntentPayload.summary(for: input)
        iconName = item.parsedDataType.iconName
        self.content = item.content
        self.kind = item.parsedDataType.displayName
        self.lastUsedAt = item.lastUsedAt
    }
}

nonisolated struct QRCodeEntityQuery: EnumerableEntityQuery, EntityStringQuery {
    @MainActor
    func allEntities() async throws -> [QRCodeEntity] {
        try Self.items().map(QRCodeEntity.init)
    }

    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [QRCodeEntity] {
        try Self.items()
            .filter { identifiers.contains($0.id) }
            .map(QRCodeEntity.init)
    }

    /// Matches what the code holds and the name the list shows for it.
    @MainActor
    func entities(matching string: String) async throws -> [QRCodeEntity] {
        try await allEntities().filter {
            $0.summary.localizedStandardContains(string)
                || $0.content.localizedStandardContains(string)
                || $0.kind.localizedStandardContains(string)
        }
    }

    @MainActor
    func suggestedEntities() async throws -> [QRCodeEntity] {
        try await Array(allEntities().prefix(10))
    }

    /// Most recently used first, as the history list shows them.
    @MainActor
    static func items() throws -> [HistoryItem] {
        try AppModelContainer.shared.mainContext.fetch(HistoryItem.recentDescriptor)
    }

    @MainActor
    static func item(id: UUID) throws -> HistoryItem? {
        try items().first { $0.id == id }
    }
}
