import AppIntents

/// Opens the generator on some content, to style it by hand: the same path as
/// the share extension, and an event or a Wi-Fi network opens in its form.
struct OpenInRadicalQRIntent: AppIntent {
    static let title = LocalizedStringResource("intent.open.title", defaultValue: "Open in Radical QR")
    static let description = IntentDescription(
        LocalizedStringResource(
            "intent.open.description",
            defaultValue: "Opens Radical QR with this content, ready to choose colors, shapes and a logo."
        ),
        categoryName: LocalizedStringResource("intent.category", defaultValue: "QR codes")
    )
    static let openAppWhenRun = true

    @Parameter(
        title: LocalizedStringResource("intent.create.content", defaultValue: "Content"),
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var content: String

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$content) in Radical QR")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw QRIntentError.emptyContent }
        DeepLinkHandler.shared.pendingContent = trimmed
        return .result()
    }
}

/// Reopens a code from history in the generator, with the style it was saved
/// with. As an `OpenIntent`, it is also what Siri and Spotlight run when the
/// user picks one of these codes.
struct OpenQRCodeIntent: OpenIntent {
    static let title = LocalizedStringResource("intent.openCode.title", defaultValue: "Open QR Code")
    static let description = IntentDescription(
        LocalizedStringResource(
            "intent.openCode.description",
            defaultValue: "Opens a QR code from your history in Radical QR, with its colors and shapes (Pro)."
        ),
        categoryName: LocalizedStringResource("intent.category", defaultValue: "QR codes")
    )

    @Parameter(title: LocalizedStringResource("intent.code.type", defaultValue: "QR Code"))
    var target: QRCodeEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        guard try QRCodeEntityQuery.item(id: target.id) != nil else { throw QRIntentError.notFound }
        DeepLinkHandler.shared.pendingHistoryItemID = target.id
        return .result()
    }
}
