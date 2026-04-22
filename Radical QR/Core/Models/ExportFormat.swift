import Foundation
import UniformTypeIdentifiers

/// Supported export formats for QR codes
enum ExportFormat: String, CaseIterable, Identifiable, Sendable {
    case png
    case jpeg
    case pdf
    case webp
    case svg

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .png: "PNG"
        case .jpeg: "JPEG"
        case .pdf: "PDF"
        case .webp: "WebP"
        case .svg: "SVG"
        }
    }

    var fileExtension: String { rawValue }

    var uniformType: UTType {
        switch self {
        case .png: .png
        case .jpeg: .jpeg
        case .pdf: .pdf
        case .webp: .webP
        case .svg: .svg
        }
    }

    var mimeType: String {
        switch self {
        case .png: "image/png"
        case .jpeg: "image/jpeg"
        case .pdf: "application/pdf"
        case .webp: "image/webp"
        case .svg: "image/svg+xml"
        }
    }

    /// Whether this format supports transparency
    var supportsTransparency: Bool {
        switch self {
        case .png, .webp, .svg, .pdf: true
        case .jpeg: false
        }
    }

    /// Whether this format is vector-based
    var isVector: Bool {
        switch self {
        case .svg, .pdf: true
        case .png, .jpeg, .webp: false
        }
    }

    /// Whether this format requires Pro subscription
    var requiresPro: Bool {
        self == .svg || self == .pdf
    }

    /// Formats available in free tier
    static var freeFormats: [ExportFormat] {
        allCases.filter { !$0.requiresPro }
    }

    /// All formats available in Pro tier
    static var proFormats: [ExportFormat] {
        allCases
    }
}

// MARK: - Export Size

struct ExportSize: Hashable, Sendable {
    let width: Int
    let height: Int

    var displayName: String {
        "\(width) × \(height)"
    }

    static let small = ExportSize(width: 256, height: 256)
    static let medium = ExportSize(width: 512, height: 512)
    static let large = ExportSize(width: 1024, height: 1024)
    static let xlarge = ExportSize(width: 2048, height: 2048)
    static let xxlarge = ExportSize(width: 4096, height: 4096)

    /// Maximum size for free tier (400px as per spec)
    static let freeMax = medium; // ExportSize(width: 400, height: 400)

    /// All standard sizes
    static let allSizes: [ExportSize] = [.small, .medium, .large, .xlarge, .xxlarge]

    /// Sizes available in free tier
    static var freeSizes: [ExportSize] {
        allSizes.filter { $0.width <= FeatureLimit.freeMaxExportSize }
    }

    /// All sizes available in Pro tier
    static var proSizes: [ExportSize] {
        allSizes
    }
}

// MARK: - Export Configuration

struct ExportConfiguration: Sendable {
    let format: ExportFormat
    let size: ExportSize
    let includeBackground: Bool

    init(format: ExportFormat, size: ExportSize, includeBackground: Bool = true) {
        self.format = format
        self.size = size
        self.includeBackground = includeBackground || !format.supportsTransparency
    }

    /// Suggested filename for export
    func suggestedFilename(prefix: String = "qrcode") -> String {
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        return "\(prefix)_\(timestamp).\(format.fileExtension)"
    }
}

// MARK: - Feature Limits

enum FeatureLimit: Sendable {
    nonisolated static let freeMaxExportSize = 512
    nonisolated static let proMaxExportSize = 4096
    nonisolated static let maxHistoryItems = 100
}
