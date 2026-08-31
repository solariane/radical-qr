import CoreImage
import Foundation

/// Reads the content back out of a picture of a QR code, so an existing code can
/// be duplicated and restyled.
///
/// This does not make the app a scanner: there is no camera, no live capture and
/// no permission to ask for. It is the same on-device Core Image detector
/// `ScannabilityChecker` already uses to verify our own codes, pointed at an
/// image the user handed over.
final class QRCodeDecoder: Sendable {
    private let detector: CIDetector?

    init() {
        detector = CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: nil,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        )
    }

    /// The payload of the first readable code in the image, or nil when the
    /// picture holds none.
    func decode(imageData: Data) -> String? {
        guard let image = CIImage(data: imageData) else { return nil }
        return decode(image: image)
    }

    func decode(image: CIImage) -> String? {
        // A photographed code often sits on a dark surface or carries alpha;
        // flattening onto white gives the detector the contrast it expects.
        let white = CIImage(color: CIColor.white).cropped(to: image.extent)
        let flattened = image.composited(over: white)

        let features = detector?.features(in: flattened) ?? []
        return features
            .compactMap { ($0 as? CIQRCodeFeature)?.messageString }
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}
