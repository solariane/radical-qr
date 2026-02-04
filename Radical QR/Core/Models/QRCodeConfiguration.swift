import SwiftUI

/// Main configuration model for QR code generation and styling
struct QRCodeConfiguration: Codable, Hashable, Sendable {
    var foregroundStyle: ForegroundStyle = .solid(.black)
    var backgroundType: BackgroundType = .white
    var roundness: CGFloat = 0.0
    var logoData: Data?
    var errorCorrectionLevel: ErrorCorrectionLevel = .medium

    // Caption
    var showCaption: Bool = false
    var captionText: String? // nil = auto-generated from content
    var captionSize: CaptionSize = .medium

    /// Caption font size relative to QR code width
    enum CaptionSize: String, Codable, Hashable, Sendable, CaseIterable {
        case small
        case medium
        case large

        var displayName: String {
            switch self {
            case .small: String(localized: "caption.size.small", defaultValue: "Small")
            case .medium: String(localized: "caption.size.medium", defaultValue: "Medium")
            case .large: String(localized: "caption.size.large", defaultValue: "Large")
            }
        }

        /// Font size as a fraction of QR code width
        var relativeFraction: CGFloat {
            switch self {
            case .small: 0.035
            case .medium: 0.045
            case .large: 0.06
            }
        }

        /// Caption area height as a fraction of QR code width
        var heightFraction: CGFloat {
            switch self {
            case .small: 0.08
            case .medium: 0.10
            case .large: 0.13
            }
        }
    }

    /// Error correction level for QR codes
    /// Higher levels allow more data recovery but reduce capacity
    enum ErrorCorrectionLevel: String, Codable, Hashable, Sendable, CaseIterable {
        case low = "L"      // ~7% recovery
        case medium = "M"   // ~15% recovery
        case quartile = "Q" // ~25% recovery
        case high = "H"     // ~30% recovery - recommended when using logo

        var displayName: String {
            switch self {
            case .low: String(localized: "config.errorCorrection.low", defaultValue: "Low")
            case .medium: String(localized: "config.errorCorrection.medium", defaultValue: "Medium")
            case .quartile: String(localized: "config.errorCorrection.quartile", defaultValue: "Quartile")
            case .high: String(localized: "config.errorCorrection.high", defaultValue: "High")
            }
        }
    }

    /// Automatically adjusts error correction when logo is present
    var effectiveErrorCorrectionLevel: ErrorCorrectionLevel {
        logoData != nil ? .high : errorCorrectionLevel
    }
}

// MARK: - Foreground Style

enum ForegroundStyle: Codable, Hashable, Sendable {
    case solid(SerializableColor)
    case gradient(GradientConfiguration)

    var primaryColor: Color {
        switch self {
        case .solid(let color):
            return color.color
        case .gradient(let config):
            return config.startColor.color
        }
    }
}

// MARK: - Gradient Configuration

struct GradientConfiguration: Codable, Hashable, Sendable {
    var startColor: SerializableColor
    var endColor: SerializableColor
    var type: GradientType = .linear
    var angle: Double = 135 // degrees, for linear gradient

    enum GradientType: String, Codable, Hashable, Sendable, CaseIterable {
        case linear
        case radial
        case angular
        case diamond

        var displayName: String {
            switch self {
            case .linear: String(localized: "gradient.type.linear", defaultValue: "Linear")
            case .radial: String(localized: "gradient.type.radial", defaultValue: "Radial")
            case .angular: String(localized: "gradient.type.angular", defaultValue: "Angular")
            case .diamond: String(localized: "gradient.type.diamond", defaultValue: "Diamond")
            }
        }

        var iconName: String {
            switch self {
            case .linear: "arrow.up.right"
            case .radial: "circle.circle"
            case .angular: "arrow.triangle.2.circlepath"
            case .diamond: "diamond"
            }
        }
    }
}

// MARK: - Background Type

enum BackgroundType: Codable, Hashable, Sendable {
    case white
    case transparent
    case transparentWithLogoCutout  // Transparent background but white cutout area for logo

    var color: Color {
        switch self {
        case .white: .white
        case .transparent, .transparentWithLogoCutout: .clear
        }
    }

    var displayName: String {
        switch self {
        case .white:
            String(localized: "background.white", defaultValue: "White")
        case .transparent:
            String(localized: "background.transparent", defaultValue: "Clear")
        case .transparentWithLogoCutout:
            String(localized: "background.logoCutout", defaultValue: "Logo Cutout")
        }
    }

    /// Whether this background type requires a logo to be useful
    var requiresLogo: Bool {
        self == .transparentWithLogoCutout
    }
}

// MARK: - Serializable Color

/// A color representation that can be encoded/decoded
struct SerializableColor: Codable, Hashable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double

    init(red: Double, green: Double, blue: Double, opacity: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }

    init(_ color: Color) {
        let resolved = color.resolve(in: EnvironmentValues())
        self.red = Double(resolved.red)
        self.green = Double(resolved.green)
        self.blue = Double(resolved.blue)
        self.opacity = Double(resolved.opacity)
    }

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }

    var cgColor: CGColor {
        CGColor(red: red, green: green, blue: blue, alpha: opacity)
    }
}

// MARK: - Predefined Colors

extension SerializableColor {
    static let black = SerializableColor(red: 0, green: 0, blue: 0)
    static let navy = SerializableColor(red: 0.118, green: 0.227, blue: 0.373) // #1e3a5f
    static let forest = SerializableColor(red: 0.176, green: 0.353, blue: 0.239) // #2d5a3d
    static let burgundy = SerializableColor(red: 0.447, green: 0.184, blue: 0.216) // #722f37
    static let charcoal = SerializableColor(red: 0.212, green: 0.271, blue: 0.310) // #36454f
    static let indigo = SerializableColor(red: 0.294, green: 0, blue: 0.510) // #4b0082

    /// Free tier colors
    static let freeColors: [SerializableColor] = [
        .black, .navy, .forest, .burgundy, .charcoal, .indigo
    ]
}

// MARK: - Predefined Gradients

extension GradientConfiguration {
    static let purpleViolet = GradientConfiguration(
        startColor: SerializableColor(red: 0.4, green: 0.494, blue: 0.918), // #667eea
        endColor: SerializableColor(red: 0.463, green: 0.294, blue: 0.635), // #764ba2
        type: .linear,
        angle: 135
    )

    static let blueCyan = GradientConfiguration(
        startColor: SerializableColor(red: 0.231, green: 0.510, blue: 0.965), // #3b82f6
        endColor: SerializableColor(red: 0.220, green: 0.784, blue: 0.835), // #38c8d5
        type: .linear,
        angle: 135
    )

    static let orangePink = GradientConfiguration(
        startColor: SerializableColor(red: 0.976, green: 0.451, blue: 0.259), // #f97316
        endColor: SerializableColor(red: 0.925, green: 0.306, blue: 0.553), // #ec4e8d
        type: .linear,
        angle: 135
    )

    /// Free tier gradients
    static let freeGradients: [GradientConfiguration] = [
        .purpleViolet, .blueCyan, .orangePink
    ]
}

// MARK: - Default Configuration

extension QRCodeConfiguration {
    static let `default` = QRCodeConfiguration()

    /// Creates a configuration with the app's signature purple-violet gradient
    static var branded: QRCodeConfiguration {
        var config = QRCodeConfiguration()
        config.foregroundStyle = .gradient(.purpleViolet)
        return config
    }
}
