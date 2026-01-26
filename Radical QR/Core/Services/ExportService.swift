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
        let moduleSize = svgSize / CGFloat(matrix.size)

        var svg = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" version="1.1" viewBox="0 0 \(Int(svgSize)) \(Int(svgSize))" width="\(Int(svgSize))" height="\(Int(svgSize))">

        """

        switch configuration.backgroundType {
        case .white:
            svg += """
              <rect width="100%" height="100%" fill="white"/>

            """
        case .transparent, .transparentWithLogoCutout:
            // For transparent backgrounds (including logo cutout), don't add background rect
            // Logo cutout is handled when drawing the logo
            break
        }

        switch configuration.foregroundStyle {
        case .gradient(let config):
            svg += generateSVGGradientDef(config, id: "qrGradient")
        case .solid:
            break
        }

        let fillAttribute: String
        switch configuration.foregroundStyle {
        case .solid(let color):
            fillAttribute = colorToHex(color)
        case .gradient:
            fillAttribute = "url(#qrGradient)"
        }

        let cornerRadius = moduleSize * configuration.roundness * 0.5

        svg += "  <g fill=\"\(fillAttribute)\">\n"

        for row in 0..<matrix.size {
            for col in 0..<matrix.size {
                guard matrix.isModuleFilled(row: row, column: col) else { continue }

                let x = CGFloat(col) * moduleSize
                let y = CGFloat(row) * moduleSize

                if configuration.roundness > 0 {
                    svg += "    <rect x=\"\(x)\" y=\"\(y)\" width=\"\(moduleSize)\" height=\"\(moduleSize)\" rx=\"\(cornerRadius)\" ry=\"\(cornerRadius)\"/>\n"
                } else {
                    svg += "    <rect x=\"\(x)\" y=\"\(y)\" width=\"\(moduleSize)\" height=\"\(moduleSize)\"/>\n"
                }
            }
        }

        svg += "  </g>\n"

        if let logoData = configuration.logoData {
            svg += generateSVGLogoElement(logoData: logoData, qrSize: svgSize)
        }

        svg += "</svg>"

        guard let data = svg.data(using: .utf8) else {
            throw ExportError.conversionFailed
        }

        return data
    }

    private func generateSVGGradientDef(_ config: GradientConfiguration, id: String) -> String {
        let startColor = colorToHex(config.startColor)
        let endColor = colorToHex(config.endColor)

        switch config.type {
        case .linear:
            let angleRad = config.angle * .pi / 180
            let x1 = 50 - cos(angleRad) * 50
            let y1 = 50 - sin(angleRad) * 50
            let x2 = 50 + cos(angleRad) * 50
            let y2 = 50 + sin(angleRad) * 50

            return """
              <defs>
                <linearGradient id="\(id)" x1="\(x1)%" y1="\(y1)%" x2="\(x2)%" y2="\(y2)%">
                  <stop offset="0%" stop-color="\(startColor)"/>
                  <stop offset="100%" stop-color="\(endColor)"/>
                </linearGradient>
              </defs>

            """

        case .radial:
            return """
              <defs>
                <radialGradient id="\(id)" cx="50%" cy="50%" r="70.7%">
                  <stop offset="0%" stop-color="\(startColor)"/>
                  <stop offset="100%" stop-color="\(endColor)"/>
                </radialGradient>
              </defs>

            """

        case .angular, .diamond:
            return """
              <defs>
                <linearGradient id="\(id)" x1="0%" y1="0%" x2="100%" y2="100%">
                  <stop offset="0%" stop-color="\(startColor)"/>
                  <stop offset="100%" stop-color="\(endColor)"/>
                </linearGradient>
              </defs>

            """
        }
    }

    private func generateSVGLogoElement(logoData: Data, qrSize: CGFloat) -> String {
        let logoSizeRatio: CGFloat = 0.25
        let logoSize = qrSize * logoSizeRatio
        let logoOffset = (qrSize - logoSize) / 2
        let padding = logoSize * 0.1
        let backgroundSize = logoSize + padding * 2
        let backgroundOffset = logoOffset - padding

        let base64 = logoData.base64EncodedString()

        let imageType: String
        if logoData.prefix(8).elementsEqual([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
            imageType = "image/png"
        } else if logoData.prefix(2).elementsEqual([0xFF, 0xD8]) {
            imageType = "image/jpeg"
        } else {
            imageType = "image/png"
        }

        return """
          <rect x="\(backgroundOffset)" y="\(backgroundOffset)" width="\(backgroundSize)" height="\(backgroundSize)" rx="\(padding)" ry="\(padding)" fill="white"/>
          <image x="\(logoOffset)" y="\(logoOffset)" width="\(logoSize)" height="\(logoSize)" href="data:\(imageType);base64,\(base64)"/>

        """
    }

    private func colorToHex(_ color: SerializableColor) -> String {
        let r = Int(color.red * 255)
        let g = Int(color.green * 255)
        let b = Int(color.blue * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
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
