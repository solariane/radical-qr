import SwiftUI
import Combine

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

    /// Detected data type for current input
    @Published private(set) var detectedDataType: DataType = .text

    /// Whether QR code is currently being generated
    @Published private(set) var isGenerating = false

    /// Current error if any
    @Published var error: GeneratorError?

    // MARK: - Services

    private let generator = QRCodeGenerator()
    private let renderer = QRCodeRenderer()
    let exportService = ExportService()

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var generateTask: Task<Void, Never>?

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

    // MARK: - Initialization

    init() {
        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
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
                previewSize: self.previewSize
            )

            guard !Task.isCancelled else { return }

            self.previewImage = image
            self.isGenerating = false
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
                size: 512
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
            exportConfig: config
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
