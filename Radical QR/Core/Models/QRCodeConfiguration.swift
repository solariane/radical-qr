import SwiftUI

/// Main configuration model for QR code generation and styling
struct QRCodeConfiguration: Codable, Hashable, Sendable {
    var foregroundStyle: ForegroundStyle = .solid(.black)
    var backgroundType: BackgroundType = .white
    var roundness: CGFloat = 0.0
    /// Independent roundness for the 3 finder-pattern "eyes" (0 = square, 1 = fully circular).
    /// Controls both the outer ring and the inner pupil of each eye.
    /// Legacy fine control — the discrete `eyeStyle` is the primary control now;
    /// kept for backward-compatible decoding / migration.
    var eyeRoundness: CGFloat = 0.0
    /// Shape of the 3 finder-pattern eyes. Replaces the old roundness slider with
    /// a curated set of looks. `dot` and `leaf` are Pro.
    var eyeStyle: EyeStyle = .square

    /// Discrete finder-pattern ("eye") shape.
    enum EyeStyle: String, Codable, Hashable, Sendable, CaseIterable {
        case square     // sharp corners (classic)
        case rounded    // softly rounded corners
        case dot        // fully circular ring + pupil
        case leaf       // petal: 3 rounded corners, 1 sharp (Pro)

        var displayName: String {
            switch self {
            case .square:  String(localized: "eye.style.square",  defaultValue: "Square")
            case .rounded: String(localized: "eye.style.rounded", defaultValue: "Rounded")
            case .dot:     String(localized: "eye.style.dot",     defaultValue: "Dot")
            case .leaf:    String(localized: "eye.style.leaf",    defaultValue: "Leaf")
            }
        }

        /// Dot and Leaf are Pro-only.
        var isPro: Bool { self == .dot || self == .leaf }

        /// Corner radius as a fraction of each sub-rect's half-width (0 = sharp,
        /// 1 = full circle). Used for square/rounded/dot; leaf is a special path.
        var cornerFraction: CGFloat {
            switch self {
            case .square:  0.0
            case .rounded: 0.45
            case .dot:     1.0
            case .leaf:    1.0
            }
        }

        var isLeaf: Bool { self == .leaf }

        /// Map a legacy `eyeRoundness` value onto the closest style (migration).
        static func inferred(fromRoundness r: CGFloat) -> EyeStyle {
            if r >= 0.85 { return .dot }
            if r >= 0.2  { return .rounded }
            return .square
        }
    }
    /// Scale factor applied to the drawn eye inside its 7-module slot.
    /// 1.0 = fills the slot (standard), <1.0 = shrunk with white margin.
    /// The finder-pattern slot itself always stays 7×7 modules for scannability.
    var eyeScale: CGFloat = 1.0
    var logoData: Data?
    var errorCorrectionLevel: ErrorCorrectionLevel = .medium

    // Caption
    var showCaption: Bool = false
    var captionText: String? // nil = auto-generated from content
    var captionSize: CaptionSize = .medium
    /// When true, the caption font shrinks so the whole text fits the width under
    /// the QR code (no truncation). When false, long captions are truncated with "…".
    var captionFitToWidth: Bool = false

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

// MARK: - Codable (graceful decoding for forward-compat)

extension QRCodeConfiguration {
    /// Custom decoder so adding a new field (e.g. `eyeRoundness`) doesn't
    /// invalidate presets/history items encoded before the field existed.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.foregroundStyle = try c.decodeIfPresent(ForegroundStyle.self, forKey: .foregroundStyle) ?? .solid(.black)
        self.backgroundType = try c.decodeIfPresent(BackgroundType.self, forKey: .backgroundType) ?? .white
        self.roundness = try c.decodeIfPresent(CGFloat.self, forKey: .roundness) ?? 0.0
        self.eyeRoundness = try c.decodeIfPresent(CGFloat.self, forKey: .eyeRoundness) ?? 0.0
        // Migrate pre-eyeStyle configs by inferring a style from the old roundness.
        self.eyeStyle = try c.decodeIfPresent(EyeStyle.self, forKey: .eyeStyle)
            ?? EyeStyle.inferred(fromRoundness: self.eyeRoundness)
        self.eyeScale = try c.decodeIfPresent(CGFloat.self, forKey: .eyeScale) ?? 1.0
        self.logoData = try c.decodeIfPresent(Data.self, forKey: .logoData)
        self.errorCorrectionLevel = try c.decodeIfPresent(ErrorCorrectionLevel.self, forKey: .errorCorrectionLevel) ?? .medium
        self.showCaption = try c.decodeIfPresent(Bool.self, forKey: .showCaption) ?? false
        self.captionText = try c.decodeIfPresent(String.self, forKey: .captionText)
        self.captionSize = try c.decodeIfPresent(CaptionSize.self, forKey: .captionSize) ?? .medium
        self.captionFitToWidth = try c.decodeIfPresent(Bool.self, forKey: .captionFitToWidth) ?? false
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
