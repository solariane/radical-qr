import SwiftUI
import CoreGraphics
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Service for exporting QR codes to various formats
final class ExportService: Sendable {
    private let renderer: QRCodeRenderer

    init(renderer: QRCodeRenderer = QRCodeRenderer()) {
        self.renderer = renderer
    }

    /// Exports a QR code to the specified format
    func export(
        input: QRInput,
        configuration: QRCodeConfiguration,
        exportConfig: ExportConfiguration
    ) async throws -> Data {
        switch exportConfig.format {
        case .svg:
            return try await exportSVG(input: input, configuration: configuration, size: exportConfig.size)
        case .pdf:
            return try await exportPDF(input: input, configuration: configuration, size: exportConfig.size)
        default:
            return try await exportRaster(input: input, configuration: configuration, exportConfig: exportConfig)
        }
    }

    // MARK: - Raster Export (PNG, JPEG, WebP)

    private func exportRaster(
        input: QRInput,
        configuration: QRCodeConfiguration,
        exportConfig: ExportConfiguration
    ) async throws -> Data {
        let size = CGFloat(exportConfig.size.width)

        guard let cgImage = renderer.renderToCGImage(
            input: input,
            configuration: configuration,
            size: size
        ) else {
            throw ExportError.renderingFailed
        }

        #if os(macOS)
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            throw ExportError.conversionFailed
        }

        let data: Data?
        switch exportConfig.format {
        case .png:
            data = bitmap.representation(using: .png, properties: [:])
        case .jpeg:
            data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
        case .webp:
            data = bitmap.representation(using: .png, properties: [:])
        default:
            throw ExportError.unsupportedFormat
        }
        #else
        let uiImage = UIImage(cgImage: cgImage)

        let data: Data?
        switch exportConfig.format {
        case .png:
            data = uiImage.pngData()
        case .jpeg:
            data = uiImage.jpegData(compressionQuality: 0.9)
        case .webp:
            if #available(iOS 14.0, *) {
                data = uiImage.heicData()
            } else {
                data = uiImage.pngData()
            }
        default:
            throw ExportError.unsupportedFormat
        }
        #endif

        guard let exportData = data else {
            throw ExportError.conversionFailed
        }

        return exportData
    }

    // MARK: - PDF Export

    private func exportPDF(
        input: QRInput,
        configuration: QRCodeConfiguration,
        size: ExportSize
    ) async throws -> Data {
        let width = CGFloat(size.width)
        let height = CGFloat(size.height)
        let rect = CGRect(origin: .zero, size: CGSize(width: width, height: height))

        let pdfData = NSMutableData()

        #if os(macOS)
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            throw ExportError.contextCreationFailed
        }

        let mediaBox = rect
        context.beginPDFPage([kCGPDFContextMediaBox as String: NSValue(rect: mediaBox)] as CFDictionary)
        #else
        UIGraphicsBeginPDFContextToData(pdfData, rect, nil)
        UIGraphicsBeginPDFPage()

        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndPDFContext()
            throw ExportError.contextCreationFailed
        }
        #endif

        if let cgImage = renderer.renderToCGImage(
            input: input,
            configuration: configuration,
            size: width
        ) {
            context.draw(cgImage, in: rect)
        }

        #if os(macOS)
        context.endPDFPage()
        context.closePDF()
        #else
        UIGraphicsEndPDFContext()
        #endif

        return pdfData as Data
    }

    // MARK: - SVG Export

    /// Generates compact, optimized SVG using single path with horizontal run-length encoding
    /// This approach produces SVGs ~5x smaller than individual element approaches
    private func exportSVG(
        input: QRInput,
        configuration: QRCodeConfiguration,
        size: ExportSize
    ) async throws -> Data {
        let generator = QRCodeGenerator()

        guard let modules = generator.extractModules(
            from: input.encodedContent,
            correctionLevel: configuration.effectiveErrorCorrectionLevel
        ),
              let matrix = QRModuleMatrix(modules: modules) else {
            throw ExportError.renderingFailed
        }

        let svgSize = CGFloat(size.width)

        var svg = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(matrix.size) \(matrix.size)" width="\(Int(svgSize))" height="\(Int(svgSize))" shape-rendering="crispEdges">
        """

        // Background
        switch configuration.backgroundType {
        case .white:
            svg += "\n<rect width=\"\(matrix.size)\" height=\"\(matrix.size)\" fill=\"#fff\"/>"
        case .transparent, .transparentWithLogoCutout:
            break
        }

        // Gradient definition if needed
        var fillAttribute = "#000"
        switch configuration.foregroundStyle {
        case .solid(let color):
            fillAttribute = colorToHex(color)
        case .gradient(let config):
            svg += generateSVGGradientDef(config, id: "g", size: matrix.size)
            fillAttribute = "url(#g)"
        }

        // Calculate logo exclusion rect if needed (for cutout mode)
        // In SVG, coordinates are in module units (viewBox)
        var exclusionRect: CGRect? = nil
        if configuration.backgroundType == .transparentWithLogoCutout,
           let logoData = configuration.logoData {
            exclusionRect = calculateSVGLogoExclusionRect(
                logoData: logoData,
                matrixSize: matrix.size
            )
        }

        // Generate optimized path - using unit coordinates (1 unit = 1 module)
        let pathData = generateOptimizedPath(
            matrix: matrix,
            roundness: configuration.roundness,
            exclusionRect: exclusionRect
        )

        svg += "\n<path fill=\"\(fillAttribute)\" d=\"\(pathData)\"/>"

        // Logo if present
        if let logoData = configuration.logoData {
            svg += generateSVGLogoElement(
                logoData: logoData,
                qrSize: CGFloat(matrix.size),
                withBackground: configuration.backgroundType == .white
            )
        }

        svg += "\n</svg>"

        guard let data = svg.data(using: .utf8) else {
            throw ExportError.conversionFailed
        }

        return data
    }

    /// Generates an optimized SVG path using horizontal run-length encoding
    /// Consecutive filled modules on the same row are merged into single rectangles
    private func generateOptimizedPath(
        matrix: QRModuleMatrix,
        roundness: CGFloat,
        exclusionRect: CGRect? = nil
    ) -> String {
        var pathCommands: [String] = []

        for row in 0..<matrix.size {
            var col = 0
            while col < matrix.size {
                guard matrix.isModuleFilled(row: row, column: col) else {
                    col += 1
                    continue
                }

                // Skip modules inside the exclusion rect (logo cutout area)
                let moduleRect = CGRect(x: CGFloat(col), y: CGFloat(row), width: 1, height: 1)
                if let exclusion = exclusionRect, exclusion.intersects(moduleRect) {
                    col += 1
                    continue
                }

                // Count consecutive filled modules (that are not in exclusion zone)
                var runLength = 1
                while col + runLength < matrix.size &&
                      matrix.isModuleFilled(row: row, column: col + runLength) {
                    let nextModuleRect = CGRect(x: CGFloat(col + runLength), y: CGFloat(row), width: 1, height: 1)
                    if let exclusion = exclusionRect, exclusion.intersects(nextModuleRect) {
                        break
                    }
                    runLength += 1
                }

                // Generate path for this run (in unit coordinates)
                if roundness > 0 {
                    let r = roundness * 0.5  // Corner radius as fraction of module
                    pathCommands.append(roundedRectPath(
                        x: CGFloat(col), y: CGFloat(row),
                        w: CGFloat(runLength), h: 1,
                        r: min(r, 0.5)
                    ))
                } else {
                    // Simple rect: M x,y h w v 1 h -w z
                    pathCommands.append("M\(col) \(row)h\(runLength)v1h-\(runLength)z")
                }

                col += runLength
            }
        }

        return pathCommands.joined()
    }

    /// Generates SVG path for a rounded rectangle
    private func roundedRectPath(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, r: CGFloat) -> String {
        let r = min(r, min(w, h) / 2)
        // M(x+r,y) h(w-2r) a(r,r,0,0,1,r,r) v(h-2r) a(r,r,0,0,1,-r,r) h(-(w-2r)) a(r,r,0,0,1,-r,-r) v(-(h-2r)) a(r,r,0,0,1,r,-r) z
        return "M\(fmt(x+r)) \(fmt(y))h\(fmt(w-2*r))a\(fmt(r)) \(fmt(r)) 0 0 1 \(fmt(r)) \(fmt(r))v\(fmt(h-2*r))a\(fmt(r)) \(fmt(r)) 0 0 1 \(fmt(-r)) \(fmt(r))h\(fmt(-(w-2*r)))a\(fmt(r)) \(fmt(r)) 0 0 1 \(fmt(-r)) \(fmt(-r))v\(fmt(-(h-2*r)))a\(fmt(r)) \(fmt(r)) 0 0 1 \(fmt(r)) \(fmt(-r))z"
    }

    private func generateSVGGradientDef(_ config: GradientConfiguration, id: String, size: Int) -> String {
        let startColor = colorToHex(config.startColor)
        let endColor = colorToHex(config.endColor)

        switch config.type {
        case .linear:
            let angleRad = config.angle * .pi / 180
            let x1 = Int(50 - cos(angleRad) * 50)
            let y1 = Int(50 - sin(angleRad) * 50)
            let x2 = Int(50 + cos(angleRad) * 50)
            let y2 = Int(50 + sin(angleRad) * 50)
            return "\n<defs><linearGradient id=\"\(id)\" x1=\"\(x1)%\" y1=\"\(y1)%\" x2=\"\(x2)%\" y2=\"\(y2)%\"><stop offset=\"0\" stop-color=\"\(startColor)\"/><stop offset=\"1\" stop-color=\"\(endColor)\"/></linearGradient></defs>"

        case .radial:
            return "\n<defs><radialGradient id=\"\(id)\" cx=\"50%\" cy=\"50%\" r=\"71%\"><stop offset=\"0\" stop-color=\"\(startColor)\"/><stop offset=\"1\" stop-color=\"\(endColor)\"/></radialGradient></defs>"

        case .angular, .diamond:
            return "\n<defs><linearGradient id=\"\(id)\" x1=\"0%\" y1=\"0%\" x2=\"100%\" y2=\"100%\"><stop offset=\"0\" stop-color=\"\(startColor)\"/><stop offset=\"1\" stop-color=\"\(endColor)\"/></linearGradient></defs>"
        }
    }

    private func colorToHex(_ color: SerializableColor) -> String {
        let r = Int(color.red * 255)
        let g = Int(color.green * 255)
        let b = Int(color.blue * 255)
        return String(format: "#%02x%02x%02x", r, g, b)
    }


    /// Calculates the exclusion rect for logo cutout in SVG (module unit coordinates)
    /// The cutout is always a SQUARE centered on the QR code
    private func calculateSVGLogoExclusionRect(logoData: Data, matrixSize: Int) -> CGRect {
        let imageSize = getImageSize(from: logoData)
        let aspectRatio = imageSize.width / imageSize.height
        let qrSize = CGFloat(matrixSize)

        let maxLogoSize = qrSize * 0.25

        let logoWidth: CGFloat
        let logoHeight: CGFloat

        if aspectRatio > 1 {
            logoWidth = maxLogoSize
            logoHeight = maxLogoSize / aspectRatio
        } else {
            logoHeight = maxLogoSize
            logoWidth = maxLogoSize * aspectRatio
        }

        // Use the larger dimension to make a SQUARE cutout
        let cutoutBase = max(logoWidth, logoHeight)
        let padding = cutoutBase * 0.12
        let cutoutSize = cutoutBase + padding * 2

        // Center the square cutout
        return CGRect(
            x: (qrSize - cutoutSize) / 2,
            y: (qrSize - cutoutSize) / 2,
            width: cutoutSize,
            height: cutoutSize
        )
    }

    private func generateSVGLogoElement(logoData: Data, qrSize: CGFloat, withBackground: Bool = true) -> String {
        // qrSize is in module units (viewBox coordinates)
        let imageSize = getImageSize(from: logoData)
        let aspectRatio = imageSize.width / imageSize.height

        let maxLogoSize = qrSize * 0.25

        let logoWidth: CGFloat
        let logoHeight: CGFloat

        if aspectRatio > 1 {
            logoWidth = maxLogoSize
            logoHeight = maxLogoSize / aspectRatio
        } else {
            logoHeight = maxLogoSize
            logoWidth = maxLogoSize * aspectRatio
        }

        let logoX = (qrSize - logoWidth) / 2
        let logoY = (qrSize - logoHeight) / 2

        let padding = min(logoWidth, logoHeight) * 0.12
        let backgroundWidth = logoWidth + padding * 2
        let backgroundHeight = logoHeight + padding * 2
        let backgroundX = logoX - padding
        let backgroundY = logoY - padding
        let cornerRadius = padding * 0.8

        // Convert image to PNG for SVG embedding (handles TIFF, HEIC, etc.)
        let (pngData, imageType) = convertToPNGForSVG(logoData)
        let base64 = pngData.base64EncodedString()

        var result = ""

        if withBackground {
            result += "\n<rect x=\"\(fmt(backgroundX))\" y=\"\(fmt(backgroundY))\" width=\"\(fmt(backgroundWidth))\" height=\"\(fmt(backgroundHeight))\" rx=\"\(fmt(cornerRadius))\" fill=\"#fff\"/>"
        }

        result += "\n<image x=\"\(fmt(logoX))\" y=\"\(fmt(logoY))\" width=\"\(fmt(logoWidth))\" height=\"\(fmt(logoHeight))\" href=\"data:\(imageType);base64,\(base64)\"/>"

        return result
    }

    /// Converts image data to PNG format for SVG embedding
    /// Returns the PNG data and MIME type
    private func convertToPNGForSVG(_ data: Data) -> (Data, String) {
        // Check if already PNG
        if data.prefix(8).elementsEqual([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
            return (data, "image/png")
        }

        // Check if JPEG - use as-is (good compression)
        if data.prefix(2).elementsEqual([0xFF, 0xD8]) {
            return (data, "image/jpeg")
        }

        // For other formats (TIFF, HEIC, etc.), convert to PNG
        #if os(macOS)
        if let nsImage = NSImage(data: data),
           let tiffData = nsImage.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [.compressionFactor: 0.9]) {
            return (pngData, "image/png")
        }
        #else
        if let uiImage = UIImage(data: data),
           let pngData = uiImage.pngData() {
            return (pngData, "image/png")
        }
        #endif

        // Fallback: return original data as PNG type
        return (data, "image/png")
    }

    private func getImageSize(from data: Data) -> CGSize {
        #if os(macOS)
        if let image = NSImage(data: data) {
            return image.size
        }
        #else
        if let image = UIImage(data: data) {
            return image.size
        }
        #endif
        // Default to square if we can't determine size
        return CGSize(width: 100, height: 100)
    }

    /// Formats a CGFloat for SVG, removing unnecessary decimals
    private func fmt(_ value: CGFloat) -> String {
        if value == value.rounded() {
            return String(Int(value))
        }
        return String(format: "%.2f", value)
    }
}

// MARK: - Export Errors

enum ExportError: LocalizedError {
    case renderingFailed
    case conversionFailed
    case contextCreationFailed
    case unsupportedFormat
    case sizeLimitExceeded

    var errorDescription: String? {
        switch self {
        case .renderingFailed:
            String(localized: "export.error.renderingFailed", defaultValue: "Failed to render QR code")
        case .conversionFailed:
            String(localized: "export.error.conversionFailed", defaultValue: "Failed to convert image data")
        case .contextCreationFailed:
            String(localized: "export.error.contextCreationFailed", defaultValue: "Failed to create graphics context")
        case .unsupportedFormat:
            String(localized: "export.error.unsupportedFormat", defaultValue: "Unsupported export format")
        case .sizeLimitExceeded:
            String(localized: "export.error.sizeLimitExceeded", defaultValue: "Export size exceeds limit")
        }
    }
}

// MARK: - Clipboard & Sharing

extension ExportService {
    /// Copies the QR code to clipboard
    @MainActor
    func copyToClipboard(
        input: QRInput,
        configuration: QRCodeConfiguration,
        size: CGFloat = 512
    ) async throws {
        guard let cgImage = renderer.renderToCGImage(
            input: input,
            configuration: configuration,
            size: size
        ) else {
            throw ExportError.renderingFailed
        }

        #if os(macOS)
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([nsImage])
        #else
        let uiImage = UIImage(cgImage: cgImage)
        UIPasteboard.general.image = uiImage
        #endif
    }

    /// Saves the QR code to a file
    func saveToFile(
        data: Data,
        filename: String,
        format: ExportFormat
    ) async throws -> URL {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)

        try data.write(to: fileURL)

        return fileURL
    }
}
