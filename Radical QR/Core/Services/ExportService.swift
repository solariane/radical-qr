import SwiftUI
import CoreGraphics
import UniformTypeIdentifiers
import QRCode

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
        let svgSize = CGFloat(size.width)

        // Create QR code document using dagronf/QRCode library
        let doc = try QRCode.Document(
            utf8String: input.encodedContent,
            errorCorrection: mapErrorCorrectionLevel(configuration.effectiveErrorCorrectionLevel)
        )

        // Configure pixel shape based on roundness
        if configuration.roundness > 0 {
            doc.design.shape.onPixels = QRCode.PixelShape.RoundedRect(
                cornerRadiusFraction: configuration.roundness
            )
        } else {
            doc.design.shape.onPixels = QRCode.PixelShape.Square()
        }

        // Configure eye shape to match roundness
        if configuration.roundness > 0.5 {
            doc.design.shape.eye = QRCode.EyeShape.RoundedRect()
        } else {
            doc.design.shape.eye = QRCode.EyeShape.Square()
        }

        // Configure foreground style
        switch configuration.foregroundStyle {
        case .solid(let color):
            doc.design.style.onPixels = QRCode.FillStyle.Solid(color.cgColor)
            doc.design.style.eye = QRCode.FillStyle.Solid(color.cgColor)
            doc.design.style.pupil = QRCode.FillStyle.Solid(color.cgColor)

        case .gradient(let gradientConfig):
            let gradient = createGradientFillStyle(from: gradientConfig)
            doc.design.style.onPixels = gradient
            doc.design.style.eye = gradient
            doc.design.style.pupil = gradient
        }

        // Configure background
        switch configuration.backgroundType {
        case .white:
            doc.design.style.background = QRCode.FillStyle.Solid(.white)
        case .transparent, .transparentWithLogoCutout:
            doc.design.style.background = QRCode.FillStyle.Solid(.clear)
        }

        // Generate SVG data
        let svgData = try doc.svgData(dimension: Int(svgSize))

        // If there's a logo, we need to inject it into the SVG
        if let logoData = configuration.logoData {
            return try injectLogoIntoSVG(
                svgData: svgData,
                logoData: logoData,
                qrSize: svgSize,
                backgroundType: configuration.backgroundType
            )
        }

        return svgData
    }

    private func mapErrorCorrectionLevel(_ level: QRCodeConfiguration.ErrorCorrectionLevel) -> QRCode.ErrorCorrection {
        switch level {
        case .low: return .low
        case .medium: return .medium
        case .quartile: return .quantize
        case .high: return .high
        }
    }

    private func createGradientFillStyle(from config: GradientConfiguration) -> QRCode.FillStyle.LinearGradient {
        // The library primarily supports linear gradients well
        // Map our gradient config to the library's format
        let startPoint: CGPoint
        let endPoint: CGPoint

        switch config.type {
        case .linear:
            let angleRad = config.angle * .pi / 180
            startPoint = CGPoint(x: 0.5 - cos(angleRad) * 0.5, y: 0.5 - sin(angleRad) * 0.5)
            endPoint = CGPoint(x: 0.5 + cos(angleRad) * 0.5, y: 0.5 + sin(angleRad) * 0.5)
        case .radial:
            // Approximate radial with diagonal linear
            startPoint = CGPoint(x: 0.5, y: 0.5)
            endPoint = CGPoint(x: 1, y: 1)
        case .angular, .diamond:
            startPoint = CGPoint(x: 0, y: 0)
            endPoint = CGPoint(x: 1, y: 1)
        }

        return QRCode.FillStyle.LinearGradient(
            try! DSFGradient(pins: [
                DSFGradient.Pin(config.startColor.cgColor, 0),
                DSFGradient.Pin(config.endColor.cgColor, 1)
            ]),
            startPoint: startPoint,
            endPoint: endPoint
        )
    }

    private func injectLogoIntoSVG(
        svgData: Data,
        logoData: Data,
        qrSize: CGFloat,
        backgroundType: BackgroundType
    ) throws -> Data {
        guard var svgString = String(data: svgData, encoding: .utf8) else {
            throw ExportError.conversionFailed
        }

        // Generate logo SVG elements
        let logoSVG = generateSVGLogoElement(
            logoData: logoData,
            qrSize: qrSize,
            withBackground: backgroundType == .transparentWithLogoCutout || backgroundType == .white
        )

        // Insert logo before closing </svg> tag
        if let range = svgString.range(of: "</svg>") {
            svgString.insert(contentsOf: logoSVG, at: range.lowerBound)
        }

        guard let resultData = svgString.data(using: .utf8) else {
            throw ExportError.conversionFailed
        }

        return resultData
    }


    private func generateSVGLogoElement(logoData: Data, qrSize: CGFloat, withBackground: Bool = true) -> String {
        // Get image dimensions to preserve aspect ratio
        let imageSize = getImageSize(from: logoData)
        let aspectRatio = imageSize.width / imageSize.height

        let maxLogoSize = qrSize * 0.25

        let logoWidth: CGFloat
        let logoHeight: CGFloat

        if aspectRatio > 1 {
            // Wider than tall
            logoWidth = maxLogoSize
            logoHeight = maxLogoSize / aspectRatio
        } else {
            // Taller than wide (or square)
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

        let base64 = logoData.base64EncodedString()

        let imageType: String
        if logoData.prefix(8).elementsEqual([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
            imageType = "image/png"
        } else if logoData.prefix(2).elementsEqual([0xFF, 0xD8]) {
            imageType = "image/jpeg"
        } else {
            imageType = "image/png"
        }

        var result = ""

        if withBackground {
            result += """
              <rect x="\(fmt(backgroundX))" y="\(fmt(backgroundY))" width="\(fmt(backgroundWidth))" height="\(fmt(backgroundHeight))" rx="\(fmt(cornerRadius))" ry="\(fmt(cornerRadius))" fill="white"/>

            """
        }

        result += """
          <image x="\(fmt(logoX))" y="\(fmt(logoY))" width="\(fmt(logoWidth))" height="\(fmt(logoHeight))" preserveAspectRatio="xMidYMid meet" href="data:\(imageType);base64,\(base64)"/>

        """

        return result
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
