import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

/// Core service for generating QR codes using Core Image
final class QRCodeGenerator: Sendable {
    private let context: CIContext

    init() {
        self.context = CIContext(options: [
            .useSoftwareRenderer: false,
            .highQualityDownsample: true
        ])
    }

    /// Generates a raw QR code CIImage from the given input
    /// - Parameters:
    ///   - input: The content to encode
    ///   - correctionLevel: Error correction level
    /// - Returns: A CIImage containing the QR code, or nil if generation fails
    func generate(
        from input: String,
        correctionLevel: QRCodeConfiguration.ErrorCorrectionLevel = .medium
    ) -> CIImage? {
        guard let data = input.data(using: .utf8) else { return nil }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = correctionLevel.rawValue

        return filter.outputImage
    }

    /// Generates a QR code with the specified configuration
    /// - Parameters:
    ///   - input: The QR input containing content and detected type
    ///   - configuration: The styling configuration
    ///   - size: The target size for the output
    /// - Returns: A rendered CGImage, or nil if generation fails
    func generate(
        from input: QRInput,
        configuration: QRCodeConfiguration,
        size: CGSize
    ) -> CGImage? {
        guard let qrImage = generate(
            from: input.encodedContent,
            correctionLevel: configuration.effectiveErrorCorrectionLevel
        ) else {
            return nil
        }

        // Scale the QR code to the target size
        let scaleX = size.width / qrImage.extent.width
        let scaleY = size.height / qrImage.extent.height
        let scale = min(scaleX, scaleY)

        let scaledImage = qrImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        return context.createCGImage(scaledImage, from: scaledImage.extent)
    }

    /// Extracts the module data (individual QR code cells) for custom rendering
    /// - Parameters:
    ///   - input: The content to encode
    ///   - correctionLevel: Error correction level
    /// - Returns: A 2D array of booleans representing the QR code modules
    func extractModules(
        from input: String,
        correctionLevel: QRCodeConfiguration.ErrorCorrectionLevel = .medium
    ) -> [[Bool]]? {
        guard let ciImage = generate(from: input, correctionLevel: correctionLevel) else {
            return nil
        }

        // Create a bitmap context to read pixel values
        let extent = ciImage.extent
        let width = Int(extent.width)
        let height = Int(extent.height)

        guard let cgImage = context.createCGImage(ciImage, from: extent) else {
            return nil
        }

        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return nil
        }

        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow

        var modules: [[Bool]] = Array(repeating: Array(repeating: false, count: width), count: height)

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                // QR codes from CIFilter are white on black, so we check for white (255)
                // After inversion, black modules are the data
                let isBlack = bytes[offset] == 0
                modules[y][x] = isBlack
            }
        }

        // CIFilter.qrCodeGenerator includes a 1-module quiet zone around the QR.
        // Strip it so the returned matrix's (0, 0) is the top-left of the actual
        // finder pattern — callers can then use `matrix.finderPatternRegions`
        // directly without accounting for the border.
        return Self.strippingQuietZone(modules)
    }

    /// Detects a uniform all-white border (quiet zone) on the outside of the
    /// module matrix and returns the matrix without it. If no quiet zone is
    /// found, the input is returned unchanged.
    private static func strippingQuietZone(_ modules: [[Bool]]) -> [[Bool]] {
        let size = modules.count
        guard size > 0, modules[0].count == size else { return modules }

        // Find the first row that contains any filled module.
        var border = 0
        for row in 0..<size {
            if modules[row].contains(true) { border = row; break }
        }
        guard border > 0, border * 2 < size else { return modules }

        // Sanity check: the same border should exist on all 4 sides.
        // (Otherwise we'd be cropping actual data.)
        let inner = size - 2 * border
        let bottomStart = size - border
        for row in bottomStart..<size where modules[row].contains(true) {
            return modules
        }
        for row in border..<bottomStart {
            if modules[row][0..<border].contains(true) { return modules }
            if modules[row][(size - border)..<size].contains(true) { return modules }
        }

        var stripped: [[Bool]] = []
        stripped.reserveCapacity(inner)
        for row in border..<(border + inner) {
            stripped.append(Array(modules[row][border..<(border + inner)]))
        }
        return stripped
    }

    /// Calculates the optimal size for the QR code based on content length
    /// - Parameter content: The content to be encoded
    /// - Returns: Recommended minimum size in points
    func recommendedSize(for content: String) -> CGFloat {
        let length = content.utf8.count
        switch length {
        case 0..<50: return 200
        case 50..<100: return 250
        case 100..<200: return 300
        case 200..<500: return 400
        default: return 500
        }
    }
}

// MARK: - Module Matrix

/// Represents the extracted module data from a QR code
struct QRModuleMatrix: Sendable {
    let modules: [[Bool]]
    let size: Int

    init?(modules: [[Bool]]) {
        guard !modules.isEmpty, modules.count == modules[0].count else {
            return nil
        }
        self.modules = modules
        self.size = modules.count
    }

    /// Returns whether the module at the given position is filled
    func isModuleFilled(row: Int, column: Int) -> Bool {
        guard row >= 0, row < size, column >= 0, column < size else {
            return false
        }
        return modules[row][column]
    }

    /// Returns the finder pattern regions (the three large squares in corners)
    var finderPatternRegions: [CGRect] {
        let patternSize = 7
        return [
            CGRect(x: 0, y: 0, width: patternSize, height: patternSize), // Top-left
            CGRect(x: size - patternSize, y: 0, width: patternSize, height: patternSize), // Top-right
            CGRect(x: 0, y: size - patternSize, width: patternSize, height: patternSize) // Bottom-left
        ]
    }

    /// Calculates the center region for logo placement
    func centerRegion(logoSizeRatio: CGFloat = 0.25) -> CGRect {
        let logoSize = Int(CGFloat(size) * logoSizeRatio)
        let offset = (size - logoSize) / 2
        return CGRect(x: offset, y: offset, width: logoSize, height: logoSize)
    }
}
