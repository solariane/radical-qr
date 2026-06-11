import CoreImage
import CoreGraphics
import Foundation

/// Result of the on-device scannability check.
struct ScannabilityResult: Equatable, Sendable {
    enum Level: Sendable { case reliable, risky, unknown }
    var level: Level
    var reason: String?     // Localized "why it might not scan" (risky only)
    var fix: ScanFix?       // Optional one-tap fix

    static let unknown = ScannabilityResult(level: .unknown, reason: nil, fix: nil)
    static let reliable = ScannabilityResult(level: .reliable, reason: nil, fix: nil)
}

/// A one-tap remedy the user can apply when a code is risky.
enum ScanFix: Equatable, Sendable {
    case raiseErrorCorrection
    case reduceRoundness
    case removeLogo

    var label: String {
        switch self {
        case .raiseErrorCorrection:
            String(localized: "scan.fix.errorCorrection", defaultValue: "Boost reliability")
        case .reduceRoundness:
            String(localized: "scan.fix.roundness", defaultValue: "Soften less")
        case .removeLogo:
            String(localized: "scan.fix.logo", defaultValue: "Remove logo")
        }
    }
}

/// Verifies that a rendered QR code actually scans, entirely on-device
/// (Core Image — no network), and explains how to fix it when it doesn't.
final class ScannabilityChecker: Sendable {
    private let detector: CIDetector?

    init() {
        detector = CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: nil,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        )
    }

    /// Renders nothing — caller passes the already-rendered code image.
    func check(cgImage: CGImage, configuration: QRCodeConfiguration) -> ScannabilityResult {
        let ciImage = CIImage(cgImage: cgImage)
        let features = detector?.features(in: ciImage) ?? []
        let decoded = (features.first as? CIQRCodeFeature)?.messageString
        let decodes = !(decoded ?? "").isEmpty

        if !decodes {
            return ScannabilityResult(level: .risky, reason: failReason(for: configuration), fix: failFix(for: configuration))
        }

        // Decodes — but flag a low-contrast design that scanners struggle with
        // in the real world (e.g. a pale code on white).
        if let contrastReason = lowContrastReason(for: configuration) {
            return ScannabilityResult(level: .risky, reason: contrastReason, fix: nil)
        }

        return .reliable
    }

    // MARK: - Diagnostics

    private func failFix(for config: QRCodeConfiguration) -> ScanFix {
        if config.roundness > 0.5 || config.eyeScale < 0.6 || config.eyeScale > 1.1 {
            return .reduceRoundness
        }
        if config.errorCorrectionLevel != .high {
            return .raiseErrorCorrection
        }
        if config.logoData != nil {
            return .removeLogo
        }
        return .raiseErrorCorrection
    }

    private func failReason(for config: QRCodeConfiguration) -> String {
        switch failFix(for: config) {
        case .reduceRoundness:
            return String(localized: "scan.reason.roundness", defaultValue: "Too much rounding can blur the pattern.")
        case .removeLogo:
            return String(localized: "scan.reason.logo", defaultValue: "The logo may be covering too much.")
        case .raiseErrorCorrection:
            return String(localized: "scan.reason.generic", defaultValue: "It didn’t scan in our test.")
        }
    }

    /// Foreground-vs-background luminance gap on a white background.
    private func lowContrastReason(for config: QRCodeConfiguration) -> String? {
        guard config.backgroundType == .white else { return nil }
        let fg = config.foregroundStyle.primaryColorComponents
        let luminance = 0.2126 * fg.r + 0.7152 * fg.g + 0.0722 * fg.b
        // Pale foreground on white → poor scan contrast.
        if luminance > 0.6 {
            return String(localized: "scan.reason.contrast", defaultValue: "Low contrast with the background.")
        }
        return nil
    }
}

private extension ForegroundStyle {
    /// Approx RGB (0…1) of the dominant foreground color.
    var primaryColorComponents: (r: Double, g: Double, b: Double) {
        let c: SerializableColor
        switch self {
        case .solid(let color): c = color
        case .gradient(let g): c = g.startColor
        }
        return (c.red, c.green, c.blue)
    }
}
