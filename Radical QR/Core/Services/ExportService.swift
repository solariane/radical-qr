import SwiftUI
import CoreGraphics
import CoreText
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
    /// - Parameter captionText: Optional resolved caption text to render below the QR code
    func export(
        input: QRInput,
        configuration: QRCodeConfiguration,
        exportConfig: ExportConfiguration,
        captionText: String? = nil
    ) async throws -> Data {
        switch exportConfig.format {
        case .svg:
            return try await exportSVG(input: input, configuration: configuration, size: exportConfig.size, captionText: captionText)
        case .pdf:
            return try await exportPDF(input: input, configuration: configuration, size: exportConfig.size, captionText: captionText)
        default:
            return try await exportRaster(input: input, configuration: configuration, exportConfig: exportConfig, captionText: captionText)
        }
    }

    // MARK: - Raster Export (PNG, JPEG, WebP)

    private func exportRaster(
        input: QRInput,
        configuration: QRCodeConfiguration,
        exportConfig: ExportConfiguration,
        captionText: String? = nil
    ) async throws -> Data {
        let size = CGFloat(exportConfig.size.width)

        guard let cgImage = renderer.renderToCGImage(
            input: input,
            configuration: configuration,
            size: size,
            captionText: captionText
        ) else {
            throw ExportError.renderingFailed
        }

        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)

        #if os(macOS)
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: imageWidth, height: imageHeight))
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
        size: ExportSize,
        captionText: String? = nil
    ) async throws -> Data {
        let width = CGFloat(size.width)
        let captionExtra: CGFloat = (captionText != nil) ? width * configuration.captionSize.heightFraction : 0
        let height = CGFloat(size.height) + captionExtra
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
            size: width,
            captionText: captionText
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
        size: ExportSize,
        captionText: String? = nil
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
        let captionModuleHeight: CGFloat = (captionText != nil)
            ? CGFloat(matrix.size) * configuration.captionSize.heightFraction
            : 0
        let totalViewBoxHeight = CGFloat(matrix.size) + captionModuleHeight
        let totalPixelHeight = svgSize * (totalViewBoxHeight / CGFloat(matrix.size))

        var svg = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(matrix.size) \(fmt(totalViewBoxHeight))" width="\(Int(svgSize))" height="\(Int(totalPixelHeight))" shape-rendering="crispEdges">
        """

        // Background
        switch configuration.backgroundType {
        case .white:
            svg += "\n<rect width=\"\(matrix.size)\" height=\"\(fmt(totalViewBoxHeight))\" fill=\"#fff\"/>"
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

        // Eyes (finder patterns) — drawn separately with even-odd fill so that
        // eyeRoundness / eyeScale are honored independently of data roundness.
        let eyesPath = generateEyesPath(
            matrix: matrix,
            eyeStyle: configuration.eyeStyle,
            eyeScale: configuration.eyeScale,
            exclusionRect: exclusionRect
        )
        if !eyesPath.isEmpty {
            // Non-square eyes need smooth curves; override the root crispEdges.
            let eyeRendering = configuration.eyeStyle != .square ? " shape-rendering=\"geometricPrecision\"" : ""
            svg += "\n<path fill=\"\(fillAttribute)\" fill-rule=\"evenodd\"\(eyeRendering) d=\"\(eyesPath)\"/>"
        }

        // Logo if present
        if let logoData = configuration.logoData {
            svg += generateSVGLogoElement(
                logoData: logoData,
                qrSize: CGFloat(matrix.size),
                withBackground: configuration.backgroundType == .white
            )
        }

        // Caption text below QR code
        if let text = captionText {
            let baseFontSize = CGFloat(matrix.size) * configuration.captionSize.relativeFraction
            let maxWidth = CGFloat(matrix.size) * 0.9
            let centerX = CGFloat(matrix.size) / 2
            let captionY = CGFloat(matrix.size) + captionModuleHeight * 0.65

            // Measure to decide whether the caption overflows the QR width.
            let measuredWidth = measureTextWidth(text, fontSize: baseFontSize)
            let overflows = measuredWidth > maxWidth

            // Fit mode: shrink the font so the whole string fits, and add textLength
            // as a hard guarantee independent of the viewer's font metrics.
            let fontSize = (configuration.captionFitToWidth && overflows)
                ? baseFontSize * (maxWidth / measuredWidth)
                : baseFontSize
            let fitAttr = (configuration.captionFitToWidth && overflows)
                ? " textLength=\"\(fmt(maxWidth))\" lengthAdjust=\"spacingAndGlyphs\""
                : ""

            // Determine fill color for caption
            let captionFill: String
            switch configuration.foregroundStyle {
            case .solid(let color):
                captionFill = colorToHex(color)
            case .gradient:
                captionFill = fillAttribute
            }

            let escapedText = text
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")

            svg += "\n<text x=\"\(fmt(centerX))\" y=\"\(fmt(captionY))\" text-anchor=\"middle\" font-family=\"system-ui, -apple-system, Helvetica, sans-serif\" font-size=\"\(fmt(fontSize))\"\(fitAttr) fill=\"\(captionFill)\">\(escapedText)</text>"
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
        let size = matrix.size

        // A module is part of the data path only if it is filled, not inside a
        // finder pattern (eyes are drawn separately so eyeRoundness/eyeScale
        // apply), and not inside the logo cutout.
        func isDataModule(_ row: Int, _ col: Int) -> Bool {
            guard matrix.isModuleFilled(row: row, column: col) else { return false }
            if isInFinderPattern(row: row, col: col, size: size) { return false }
            if let exclusion = exclusionRect,
               exclusion.intersects(CGRect(x: CGFloat(col), y: CGFloat(row), width: 1, height: 1)) {
                return false
            }
            return true
        }

        for row in 0..<size {
            var col = 0
            while col < size {
                guard isDataModule(row, col) else {
                    col += 1
                    continue
                }

                // Count consecutive data modules
                var runLength = 1
                while col + runLength < size && isDataModule(row, col + runLength) {
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

    /// True if the module is inside any of the three 7×7 finder patterns (eyes).
    /// Mirrors `QRCodeRenderer.isInFinderPattern` so SVG and bitmap agree.
    private func isInFinderPattern(row: Int, col: Int, size: Int, patternSize: Int = 7) -> Bool {
        if row < patternSize && col < patternSize { return true }            // top-left
        if row < patternSize && col >= size - patternSize { return true }    // top-right
        if row >= size - patternSize && col < patternSize { return true }    // bottom-left
        return false
    }

    /// Builds the SVG path for the three finder-pattern eyes, mirroring
    /// `QRCodeRenderer.addEyeSubpath`: each eye is outer ring + inner cutout +
    /// pupil, meant to be filled with `fill-rule="evenodd"` so the ring and pupil
    /// stay solid while the gap between them is carved out. Honors `eyeRoundness`
    /// and `eyeScale` (the bug: the old SVG path ignored both).
    private func generateEyesPath(
        matrix: QRModuleMatrix,
        eyeStyle: QRCodeConfiguration.EyeStyle,
        eyeScale: CGFloat,
        exclusionRect: CGRect? = nil
    ) -> String {
        var commands: [String] = []
        let clampedScale = max(0.3, min(eyeScale, 1.15))

        for region in matrix.finderPatternRegions {
            // Contract the 7×7 slot around its center by (1 - scale). Module size
            // is 1 in viewBox units, so ring thickness == clampedScale.
            let shrink = region.width * (1 - clampedScale) / 2
            let outer = region.insetBy(dx: shrink, dy: shrink)

            if let exclusion = exclusionRect, exclusion.intersects(outer) { continue }

            let ring = clampedScale
            let innerCutout = outer.insetBy(dx: ring, dy: ring)
            let pupil = outer.insetBy(dx: ring * 2, dy: ring * 2)

            for rect in [outer, innerCutout, pupil] where rect.width > 0 && rect.height > 0 {
                commands.append(eyeShapePath(rect, style: eyeStyle))
            }
        }

        return commands.joined()
    }

    /// One eye sub-rectangle as an SVG subpath, in the requested style. `leaf`
    /// rounds three corners and keeps the top-left sharp; others use a uniform
    /// radius. Mirrors `QRCodeRenderer.addEyeShape`.
    private func eyeShapePath(_ rect: CGRect, style: QRCodeConfiguration.EyeStyle) -> String {
        let r = (rect.width / 2) * style.cornerFraction
        if style.isLeaf {
            return cornerRectPath(rect, tl: 0, tr: r, br: r, bl: r)
        }
        if r > 0 {
            return roundedRectPath(x: rect.minX, y: rect.minY, w: rect.width, h: rect.height, r: r)
        }
        return "M\(fmt(rect.minX)) \(fmt(rect.minY))h\(fmt(rect.width))v\(fmt(rect.height))h\(fmt(-rect.width))z"
    }

    /// SVG path for a rectangle with an independent radius per corner (arcs).
    private func cornerRectPath(_ rect: CGRect, tl: CGFloat, tr: CGFloat, br: CGFloat, bl: CGFloat) -> String {
        let (x, y, w, h) = (rect.minX, rect.minY, rect.width, rect.height)
        func arc(_ r: CGFloat, _ ex: CGFloat, _ ey: CGFloat) -> String {
            r > 0 ? "A\(fmt(r)) \(fmt(r)) 0 0 1 \(fmt(ex)) \(fmt(ey))" : "L\(fmt(ex)) \(fmt(ey))"
        }
        var p = "M\(fmt(x + tl)) \(fmt(y))"
        p += "H\(fmt(x + w - tr))" + arc(tr, x + w, y + tr)
        p += "V\(fmt(y + h - br))" + arc(br, x + w - br, y + h)
        p += "H\(fmt(x + bl))" + arc(bl, x, y + h - bl)
        p += "V\(fmt(y + tl))" + arc(tl, x + tl, y)
        return p + "Z"
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
        // Clamp to sRGB range — extended color spaces (Display P3) can
        // produce components outside 0…1 which break hex formatting.
        let r = Int((min(max(color.red, 0), 1) * 255).rounded())
        let g = Int((min(max(color.green, 0), 1) * 255).rounded())
        let b = Int((min(max(color.blue, 0), 1) * 255).rounded())
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

    /// Prepares image data for SVG embedding
    /// Keeps native format for PNG/JPEG/WebP, converts other formats (TIFF, HEIC, etc.) to PNG or JPEG
    private func convertToPNGForSVG(_ data: Data) -> (Data, String) {
        // Check if already PNG - use as-is
        if data.prefix(8).elementsEqual([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
            return (data, "image/png")
        }

        // Check if JPEG - use as-is
        if data.prefix(2).elementsEqual([0xFF, 0xD8]) {
            return (data, "image/jpeg")
        }

        // Check if WebP - use as-is (RIFF....WEBP signature)
        if data.prefix(4).elementsEqual([0x52, 0x49, 0x46, 0x46]) && // "RIFF"
           data.count > 11 &&
           data[8...11].elementsEqual([0x57, 0x45, 0x42, 0x50]) { // "WEBP"
            return (data, "image/webp")
        }

        // For other formats (TIFF, HEIC, etc.), convert to web-compatible format
        #if os(macOS)
        if let nsImage = NSImage(data: data),
           let tiffData = nsImage.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData) {
            // Check if image has alpha channel
            if bitmap.hasAlpha {
                // Use PNG to preserve transparency
                if let pngData = bitmap.representation(using: .png, properties: [:]) {
                    return (pngData, "image/png")
                }
            } else {
                // Use JPEG for opaque images (better compression)
                if let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) {
                    return (jpegData, "image/jpeg")
                }
            }
        }
        #else
        if let uiImage = UIImage(data: data) {
            // Check if image has alpha
            let hasAlpha = uiImage.cgImage?.alphaInfo != .none &&
                           uiImage.cgImage?.alphaInfo != .noneSkipLast &&
                           uiImage.cgImage?.alphaInfo != .noneSkipFirst

            if hasAlpha {
                if let pngData = uiImage.pngData() {
                    return (pngData, "image/png")
                }
            } else {
                if let jpegData = uiImage.jpegData(compressionQuality: 0.85) {
                    return (jpegData, "image/jpeg")
                }
            }
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

    /// Measures the rendered width of `text` at the given font size (in the same
    /// units as `fontSize`). Uses Helvetica to stay consistent with the bitmap
    /// renderer's caption measurement.
    private func measureTextWidth(_ text: String, fontSize: CGFloat) -> CGFloat {
        let font = CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: text, attributes: [.font: font])
        )
        return CTLineGetBoundsWithOptions(line, .useOpticalBounds).width
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
        size: CGFloat = 512,
        captionText: String? = nil
    ) async throws {
        guard let cgImage = renderer.renderToCGImage(
            input: input,
            configuration: configuration,
            size: size,
            captionText: captionText
        ) else {
            throw ExportError.renderingFailed
        }

        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)

        #if os(macOS)
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: imageWidth, height: imageHeight))
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
