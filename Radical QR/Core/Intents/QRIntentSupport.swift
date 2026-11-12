import AppIntents
import SwiftUI

// What the App Intents share: the format choice, the errors, and the one place
// that turns spoken or shortcut text into the payload the generator would encode.

// MARK: - Format

/// The export formats, as Shortcuts and Siri list them.
nonisolated enum QRFormatOption: String, AppEnum {
    case png, jpeg, webp, pdf, svg

    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("intent.format.type", defaultValue: "Format")
    )

    // Format names, the same in every language (the catalog marks them so).
    static let caseDisplayRepresentations: [QRFormatOption: DisplayRepresentation] = [
        .png: DisplayRepresentation(title: "PNG"),
        .jpeg: DisplayRepresentation(title: "JPEG"),
        .webp: DisplayRepresentation(title: "WebP"),
        .pdf: DisplayRepresentation(title: "PDF"),
        .svg: DisplayRepresentation(title: "SVG"),
    ]

    var exportFormat: ExportFormat {
        switch self {
        case .png: .png
        case .jpeg: .jpeg
        case .webp: .webp
        case .pdf: .pdf
        case .svg: .svg
        }
    }
}

// MARK: - Errors

nonisolated enum QRIntentError: Error, CustomLocalizedStringResourceConvertible {
    case emptyContent
    case requiresPro
    case notFound
    case renderingFailed

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .emptyContent:
            LocalizedStringResource("intent.error.empty", defaultValue: "There is nothing to put in the QR code.")
        case .requiresPro:
            LocalizedStringResource(
                "intent.error.pro",
                defaultValue: "This option is part of Radical QR Pro. Open the app to unlock it."
            )
        case .notFound:
            LocalizedStringResource("intent.error.notFound", defaultValue: "This QR code is no longer in your history.")
        case .renderingFailed:
            LocalizedStringResource("intent.error.rendering", defaultValue: "The QR code could not be drawn.")
        }
    }
}

// MARK: - Payload

nonisolated enum QRIntentPayload {
    /// What the generator would encode for this text. A clear event, Wi-Fi
    /// network, contact or address becomes its structured form, exactly as a
    /// paste or a share does; anything less certain stays as written.
    static func input(from text: String) throws -> QRInput {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw QRIntentError.emptyContent }

        let type = DataTypeDetector.detect(trimmed)
        if let detection = ContentDetector.detect(in: trimmed, type: type), detection.confidence == .high {
            return QRInput(content: detection.draft.encoded, detectedType: detection.draft.dataType)
        }
        return QRInput(content: trimmed, detectedType: type)
    }

    /// The caption the generator would draw under this code, if any.
    @MainActor
    static func caption(for input: QRInput, configuration: QRCodeConfiguration) -> String? {
        guard configuration.showCaption else { return nil }
        if let custom = configuration.captionText, !custom.isEmpty { return custom }
        return CaptionGenerator.defaultCaption(for: input)
    }

    /// A short line naming what the code holds: "Wi-Fi · Ma Box", a site, a name.
    static func summary(for input: QRInput) -> String {
        if let summary = DataTypeDetector.summarize(input.content, for: input.detectedType), !summary.isEmpty {
            return summary
        }
        let firstLine = input.content.split(whereSeparator: \.isNewline).first.map(String.init) ?? input.content
        return String(firstLine.prefix(60))
    }
}

// MARK: - Snippet

/// What Siri and Shortcuts show after a code is made: the code itself, so it
/// can be scanned straight from the screen, and what it holds.
struct QRCodeSnippetView: View {
    let image: CGImage
    let summary: String

    var body: some View {
        VStack(spacing: 10) {
            Image(decorative: image, scale: 1)
                .resizable()
                .interpolation(.none)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 220)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(verbatim: summary)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: summary))
    }
}
