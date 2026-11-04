import CoreImage
import CoreGraphics
import Foundation

/// Result of the on-device scannability check.
nonisolated struct ScannabilityResult: Equatable, Sendable {
    enum Level: Sendable { case reliable, risky, unknown }
    var level: Level
    var reason: String?     // Localized "why it might not scan" (risky only)
    var fix: ScanFix?       // Optional one-tap fix

    static let unknown = ScannabilityResult(level: .unknown, reason: nil, fix: nil)
    static let reliable = ScannabilityResult(level: .reliable, reason: nil, fix: nil)
}

/// A one-tap remedy the user can apply when a code is risky.
nonisolated enum ScanFix: Equatable, Sendable {
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
///
/// `nonisolated` on purpose: the generator checks scannability from a detached
/// task so a 512px render + decode never blocks the main actor.
nonisolated final class ScannabilityChecker: Sendable {
    /// Built per check rather than stored: `CIDetector` is not `Sendable` and has
    /// no documented thread safety, while the check runs on a detached task. One
    /// QR detector is cheap next to the 512px render it inspects.
    private func makeDetector() -> CIDetector? {
        CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: nil,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        )
    }

    /// Renders nothing — caller passes the already-rendered code image.
    func check(cgImage: CGImage, configuration: QRCodeConfiguration) -> ScannabilityResult {
        // A transparent background leaves (0,0,0,0) pixels, which the detector
        // reads as black: the whole image goes dark and nothing decodes, so a
        // perfectly good black-on-clear code was reported as risky. Flatten onto
        // white first — the same light surface the code will be placed on. An
        // opaque background, coloured or not, is unaffected.
        var ciImage = flattenedOnWhite(cgImage)
        let ink = configuration.foregroundStyle.inkColor
        let surface = configuration.backgroundFill ?? .white
        let contrast = ContrastPalette.contrast(ink, surface)
        // A light code on a dark background: test the code the way a scanner
        // that handles inverted codes sees it, then say that some don't.
        let inverted = ContrastPalette.luminance(ink) > ContrastPalette.luminance(surface)
        if inverted {
            ciImage = ciImage.applyingFilter("CIColorInvert")
        }
        let features = makeDetector()?.features(in: ciImage) ?? []
        let decoded = (features.first as? CIQRCodeFeature)?.messageString
        let decodes = !(decoded ?? "").isEmpty

        // Too little contrast explains a failure better than the shape does, and
        // no error-correction level fixes it.
        if contrast < ContrastPalette.riskyContrast {
            return ScannabilityResult(level: .risky, reason: Self.contrastReason, fix: nil)
        }

        if !decodes {
            return ScannabilityResult(level: .risky, reason: failReason(for: configuration), fix: failFix(for: configuration))
        }

        if inverted {
            return ScannabilityResult(
                level: .risky,
                reason: String(
                    localized: "scan.reason.inverted",
                    defaultValue: "Light on dark: some older scanner apps can’t read it.",
                    comment: "Why a QR code may not scan: its pattern is lighter than its background. Phone cameras read it; some older scanning apps do not."
                ),
                fix: nil
            )
        }

        return .reliable
    }

    private static var contrastReason: String {
        String(localized: "scan.reason.contrast", defaultValue: "Low contrast with the background.")
    }

    /// The rendered code composited over opaque white.
    private func flattenedOnWhite(_ cgImage: CGImage) -> CIImage {
        let source = CIImage(cgImage: cgImage)
        let white = CIImage(color: CIColor.white).cropped(to: source.extent)
        return source.composited(over: white)
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

}

nonisolated private extension ForegroundStyle {
    /// The dominant foreground colour: the caption's colour too.
    var inkColor: SerializableColor {
        switch self {
        case .solid(let color): color
        case .gradient(let g): g.startColor
        }
    }
}
