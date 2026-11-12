import AppIntents
import SwiftData
import SwiftUI

/// Makes a QR code without opening the app and hands back the file: Siri shows
/// it to scan, Shortcuts passes it on (save, AirDrop, attach to a note). Text
/// that is clearly an event, a Wi-Fi network, a contact or an address is
/// encoded as one, as when it is pasted in the app. Free and Pro limits are the
/// app's: PDF, SVG, sizes above 512 px and saved styles need Pro.
struct CreateQRCodeIntent: AppIntent {
    static let title = LocalizedStringResource("intent.create.title", defaultValue: "Create QR Code")
    static let description = IntentDescription(
        LocalizedStringResource(
            "intent.create.description",
            defaultValue: "Makes a QR code from a link, a text, a Wi-Fi network, a contact or an event, and returns it as an image or vector file. Nothing leaves the device."
        ),
        categoryName: LocalizedStringResource("intent.category", defaultValue: "QR codes"),
        searchKeywords: ["QR", "QR code", "barcode", "Wi-Fi", "vCard", "link"]
    )

    @Parameter(
        title: LocalizedStringResource("intent.create.content", defaultValue: "Content"),
        description: LocalizedStringResource(
            "intent.create.content.description",
            defaultValue: "What scanning the code gives: a link, any text, an address, Wi-Fi details, a contact card or an event."
        ),
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var content: String

    @Parameter(
        title: LocalizedStringResource("intent.create.style", defaultValue: "Style"),
        description: LocalizedStringResource(
            "intent.create.style.description",
            defaultValue: "One of the styles saved in the app (Pro). Without it, the code is black on white."
        )
    )
    var style: SavedStyleEntity?

    @Parameter(
        title: LocalizedStringResource("intent.create.format", defaultValue: "Format"),
        description: LocalizedStringResource(
            "intent.create.format.description",
            defaultValue: "PNG, JPEG or WebP for an image; PDF or SVG for print and design tools (Pro)."
        ),
        default: .png
    )
    var format: QRFormatOption

    @Parameter(
        title: LocalizedStringResource("intent.create.size", defaultValue: "Size in Pixels"),
        description: LocalizedStringResource(
            "intent.create.size.description",
            defaultValue: "Width of the square image, up to 512 px, or 4096 px with Pro."
        ),
        default: 512,
        inclusiveRange: (64, 4096)
    )
    var size: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Create a QR code of \(\.$content)") {
            \.$style
            \.$format
            \.$size
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> & ProvidesDialog & ShowsSnippetView {
        let input = try QRIntentPayload.input(from: content)

        let purchases = PurchaseManager.shared
        await purchases.refreshEntitlements()
        let format = format.exportFormat
        if !purchases.isPro, style != nil || format.requiresPro || size > FeatureLimit.freeMaxExportSize {
            throw QRIntentError.requiresPro
        }

        let configuration: QRCodeConfiguration
        if let style, let preset = try SavedStyleQuery.preset(id: style.id) {
            configuration = preset.getConfiguration()
        } else {
            configuration = .default
        }
        let caption = QRIntentPayload.caption(for: input, configuration: configuration)

        let exportConfig = ExportConfiguration(format: format, size: ExportSize(width: size, height: size))
        let data = try await ExportService().export(
            input: input,
            configuration: configuration,
            exportConfig: exportConfig,
            captionText: caption
        )
        let file = IntentFile(
            data: data,
            filename: exportConfig.suggestedFilename(for: input),
            type: format.uniformType
        )

        // The snippet is always a picture, whatever the file format.
        guard let preview = QRCodeRenderer().renderToCGImage(
            input: input,
            configuration: configuration,
            size: 440,
            captionText: caption
        ) else {
            throw QRIntentError.renderingFailed
        }

        if purchases.isPro {
            HistoryItem.record(
                content: input.content,
                dataType: input.detectedType,
                configuration: configuration,
                in: AppModelContainer.shared.mainContext
            )
        }

        let summary = QRIntentPayload.summary(for: input)
        return .result(
            value: file,
            dialog: IntentDialog(LocalizedStringResource("intent.create.done", defaultValue: "Here is your QR code.")),
            view: QRCodeSnippetView(image: preview, summary: summary)
        )
    }
}
