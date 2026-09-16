import SwiftUI
import Combine
import SwiftData

/// ViewModel for the main QR code generator
@MainActor
final class GeneratorViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Current input text
    @Published var inputText: String = ""

    /// Current QR code configuration
    @Published var configuration = QRCodeConfiguration.default

    /// Generated QR code preview image
    @Published private(set) var previewImage: Image?

    /// On-device scannability of the current code (does it actually decode?).
    @Published private(set) var scannability: ScannabilityResult = .unknown

    /// Detected data type for current input
    @Published private(set) var detectedDataType: DataType = .text

    /// Whether QR code is currently being generated
    @Published private(set) var isGenerating = false

    /// Current error if any
    @Published var error: GeneratorError?

    /// The event being edited, when the input is one — the QR content is
    /// regenerated from it on every change.
    @Published private(set) var eventDraft: EventDraft?

    /// A date found in the text but not clearly enough to switch on our own.
    @Published private(set) var eventSuggestion: EventDraft?

    /// Bumped when the input just turned into an event, so the view opens the editor.
    @Published private(set) var eventEditorRequest = 0

    /// Changes whenever a different event is loaded (not when the current one is
    /// edited), so the editor drops the folded/unfolded state of the previous one.
    @Published private(set) var eventGeneration = 0

    // MARK: - Services

    private let generator = QRCodeGenerator()
    private let renderer = QRCodeRenderer()
    private let scannabilityChecker = ScannabilityChecker()
    let exportService = ExportService()

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var generateTask: Task<Void, Never>?
    private var eventDetectionTask: Task<Void, Never>?

    /// The text an event was made from, restored by "Keep as text".
    private(set) var eventSourceText: String?
    /// Texts the user chose to keep as text — never offered again this session.
    private var declinedEventSources: Set<String> = []
    /// The last VEVENT we wrote, so our own writes are not re-analysed.
    private var lastEncodedEvent: String?

    /// Typed text waits for a pause before a suggestion appears.
    private let typingDetectionDelay: Duration = .milliseconds(600)

    // Preview size for live preview
    private let previewSize: CGFloat = 300

    // Debounce delay for live preview
    private let debounceDelay: TimeInterval = 0.2

    // MARK: - Computed Properties

    /// The current QR input based on text and detected type
    var currentInput: QRInput? {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return QRInput(content: inputText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Whether the current input is valid for QR generation
    var hasValidInput: Bool {
        currentInput != nil
    }

    /// Enriched URL metadata (social profiles, deep links) for the current input
    var urlMetadata: URLMetadata? {
        guard detectedDataType == .url else { return nil }
        return URLMetadataExtractor.extract(from: inputText)
    }

    /// Complex data types where raw content shouldn't be displayed in the text field
    /// (e.g. vCard, iCal and Wi-Fi blobs are unreadable).
    private static let complexTypesForSummaryOverride: Set<DataType> = [.vcard, .icalendar, .wifi]

    /// When the input is a complex type, returns a clean summary to show in place
    /// of the raw text. Returns `nil` for simple types (URL, email, phone, etc.),
    /// letting the text field display the content normally.
    var inputSummaryOverride: InputSummary? {
        guard hasValidInput,
              Self.complexTypesForSummaryOverride.contains(detectedDataType) else {
            return nil
        }
        let title = detectedDataType.displayName
        let detail = DataTypeDetector.summarize(inputText, for: detectedDataType)
        return InputSummary(
            iconName: detectedDataType.iconName,
            title: title,
            detail: detail
        )
    }

    /// Resolved caption text: user override or auto-generated from content
    var resolvedCaptionText: String? {
        guard configuration.showCaption, let input = currentInput else { return nil }
        if let custom = configuration.captionText, !custom.isEmpty {
            return custom
        }
        return CaptionGenerator.defaultCaption(for: input)
    }

    // MARK: - Initialization

    init() {
        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Read before the change lands: `inputText` still holds the old value here.
        $inputText
            .removeDuplicates()
            .sink { [weak self] text in
                self?.inputWillChange(to: text)
            }
            .store(in: &cancellables)

        // Detect data type as user types
        $inputText
            .map { text -> DataType in
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return .text }
                return DataTypeDetector.detect(trimmed)
            }
            .assign(to: &$detectedDataType)

        // Debounced QR generation
        $inputText
            .debounce(for: .seconds(debounceDelay), scheduler: DispatchQueue.main)
            .combineLatest($configuration)
            .sink { [weak self] _, _ in
                self?.generatePreview()
            }
            .store(in: &cancellables)

        // Also regenerate when configuration changes
        $configuration
            .dropFirst()
            .debounce(for: .seconds(debounceDelay), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.generatePreview()
            }
            .store(in: &cancellables)
    }

    // MARK: - Preview Generation

    func generatePreview() {
        // Cancel any pending generation
        generateTask?.cancel()

        guard let input = currentInput else {
            previewImage = nil
            scannability = .unknown
            return
        }

        isGenerating = true

        generateTask = Task { [weak self] in
            guard let self = self else { return }

            // Small delay to allow cancellation
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

            guard !Task.isCancelled else { return }

            let image = self.renderer.preview(
                input: input,
                configuration: self.configuration,
                previewSize: self.previewSize,
                captionText: self.resolvedCaptionText
            )

            guard !Task.isCancelled else { return }

            self.previewImage = image
            self.isGenerating = false

            // Verify the code actually scans — render + decode off the main actor.
            let cfg = self.configuration
            let renderer = self.renderer
            let checker = self.scannabilityChecker
            let result = await Task.detached(priority: .utility) { () -> ScannabilityResult in
                guard let cg = renderer.renderToCGImage(
                    input: input, configuration: cfg, size: 512, captionText: nil
                ) else { return .unknown }
                return checker.check(cgImage: cg, configuration: cfg)
            }.value

            guard !Task.isCancelled else { return }
            self.scannability = result
        }
    }

    /// Applies the suggested one-tap fix for a risky code.
    func applyScanFix(_ fix: ScanFix) {
        switch fix {
        case .raiseErrorCorrection:
            configuration.errorCorrectionLevel = .high
        case .reduceRoundness:
            configuration.roundness = min(configuration.roundness, 0.3)
            configuration.eyeScale = min(max(configuration.eyeScale, 0.9), 1.0)
            if configuration.eyeStyle == .leaf || configuration.eyeStyle == .dot {
                configuration.eyeStyle = .rounded
            }
        case .removeLogo:
            configuration.logoData = nil
        }
    }

    // MARK: - Export Actions

    /// Copies the QR code to clipboard
    func copyToClipboard() async {
        guard let input = currentInput else { return }

        do {
            try await exportService.copyToClipboard(
                input: input,
                configuration: configuration,
                size: 512,
                captionText: resolvedCaptionText
            )
        } catch {
            self.error = .exportFailed(error.localizedDescription)
        }
    }

    /// Exports the QR code with the given configuration
    func export(config: ExportConfiguration) async throws -> Data {
        guard let input = currentInput else {
            throw GeneratorError.noInput
        }

        return try await exportService.export(
            input: input,
            configuration: configuration,
            exportConfig: config,
            captionText: resolvedCaptionText
        )
    }

    /// Saves the QR code to a file and returns the URL
    func saveToFile(config: ExportConfiguration) async throws -> URL {
        let data = try await export(config: config)
        let filename = config.suggestedFilename()

        return try await exportService.saveToFile(
            data: data,
            filename: filename,
            format: config.format
        )
    }

    // MARK: - Style Management

    /// Applies a preset gradient style
    func applyPresetGradient(_ gradient: GradientConfiguration) {
        configuration.foregroundStyle = .gradient(gradient)
    }

    /// Applies a preset solid color
    func applyPresetColor(_ color: SerializableColor) {
        configuration.foregroundStyle = .solid(color)
    }

    /// Resets configuration to defaults
    func resetConfiguration() {
        configuration = .default
    }

    /// Applies a style preset
    @MainActor
    func applyStylePreset(_ preset: StylePreset) {
        configuration = preset.getConfiguration()
    }

    // MARK: - Input Handling

    /// Sets input from a dropped file
    func handleFileDrop(_ url: URL) {
        if let content = DataTypeDetector.extractContent(from: url) {
            inputText = content
        }
    }

    /// Clears the current input
    func clearInput() {
        inputText = ""
        previewImage = nil
    }

    // MARK: - Events

    /// Decides whether new input is, might be, or has stopped being an event.
    private func inputWillChange(to text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != lastEncodedEvent else { return }

        let previous = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        eventDetectionTask?.cancel()
        eventSuggestion = nil
        eventDraft = nil
        eventSourceText = nil
        lastEncodedEvent = nil
        guard !trimmed.isEmpty else { return }

        let type = DataTypeDetector.detect(trimmed)
        if type == .icalendar {
            // From history, a file or a share: editable when we could have written it.
            eventDraft = EventDraft(icalendar: trimmed)
            eventGeneration += 1
            return
        }
        guard type == .text || type == .phone, !declinedEventSources.contains(trimmed) else { return }

        // Same rule the scroll anchoring uses: a paste, drop or share arrives whole.
        let arrivedWhole = previous.isEmpty || abs(trimmed.count - previous.count) > 5
        eventDetectionTask = Task { [weak self, typingDetectionDelay] in
            if !arrivedWhole {
                try? await Task.sleep(for: typingDetectionDelay)
            } else {
                await Task.yield()
            }
            guard !Task.isCancelled, let self,
                  self.inputText.trimmingCharacters(in: .whitespacesAndNewlines) == trimmed,
                  let detection = EventDetector.detect(in: trimmed, requireFullCoverage: type == .phone) else { return }

            if detection.confidence == .high && arrivedWhole {
                self.applyEvent(detection.draft, from: trimmed)
            } else {
                self.eventSuggestion = detection.draft
            }
        }
    }

    /// Turns the offered suggestion into the event being edited.
    func acceptEventSuggestion() {
        guard let draft = eventSuggestion else { return }
        applyEvent(draft, from: inputText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func dismissEventSuggestion() {
        declinedEventSources.insert(inputText.trimmingCharacters(in: .whitespacesAndNewlines))
        eventSuggestion = nil
    }

    func updateEventDraft(_ draft: EventDraft) {
        guard eventDraft != nil else { return }
        eventDraft = draft
        encode(draft)
    }

    /// Puts back what was pasted and stops reading it as an event.
    func keepAsText() {
        guard let source = eventSourceText else { return }
        declinedEventSources.insert(source)
        lastEncodedEvent = nil
        inputText = source
    }

    private func applyEvent(_ draft: EventDraft, from source: String) {
        eventSuggestion = nil
        eventDraft = draft
        encode(draft)
        eventSourceText = source
        eventGeneration += 1
        eventEditorRequest += 1
    }

    private func encode(_ draft: EventDraft) {
        let content = draft.icalendar
        lastEncodedEvent = content
        inputText = content
    }

    // MARK: - History

    /// Records a history entry for the current input & configuration. De-duplicates
    /// by content: if an entry with the same content already exists, its config is
    /// refreshed and usage count bumped instead of inserting a duplicate.
    /// Enforces `FeatureLimit.maxHistoryItems` by pruning the oldest entries.
    func recordHistory(in context: ModelContext) {
        guard let input = currentInput else { return }
        let content = input.content

        let descriptor = FetchDescriptor<HistoryItem>(
            sortBy: [SortDescriptor(\.lastUsedAt, order: .reverse)]
        )
        let items = (try? context.fetch(descriptor)) ?? []

        if let existing = items.first(where: { $0.content == content }) {
            existing.setConfiguration(configuration)
            existing.markUsed()
        } else {
            let newItem = HistoryItem(
                content: content,
                dataType: detectedDataType,
                configuration: configuration
            )
            context.insert(newItem)

            // Prune anything beyond the cap (oldest first).
            let overflow = items.count + 1 - FeatureLimit.maxHistoryItems
            if overflow > 0 {
                let toDelete = items.suffix(overflow)
                for item in toDelete {
                    context.delete(item)
                }
            }
        }
    }

    /// Loads a history item into the generator, replacing both the current input
    /// and configuration. Bumps the item's usage count.
    func loadFromHistory(_ item: HistoryItem) {
        configuration = item.getConfiguration()
        inputText = item.content
        item.markUsed()
    }
}

// MARK: - Input Summary

/// Compact summary shown in place of raw input when the content is a complex
/// format (vCard, iCal, Wi-Fi) where the raw blob isn't useful to the user.
struct InputSummary: Equatable {
    let iconName: String
    let title: String
    let detail: String?
}

// MARK: - Errors

enum GeneratorError: LocalizedError, Identifiable {
    case noInput
    case generationFailed
    case exportFailed(String)

    var id: String {
        switch self {
        case .noInput: "noInput"
        case .generationFailed: "generationFailed"
        case .exportFailed(let msg): "exportFailed_\(msg)"
        }
    }

    var errorDescription: String? {
        switch self {
        case .noInput:
            String(localized: "generator.error.noInput", defaultValue: "Please enter text or drop a file")
        case .generationFailed:
            String(localized: "generator.error.generationFailed", defaultValue: "Failed to generate QR code")
        case .exportFailed(let message):
            String(localized: "generator.error.exportFailed", defaultValue: "Export failed") + ": \(message)"
        }
    }
}
