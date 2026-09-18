import XCTest
import CoreGraphics
@testable import Radical_QR

/// Every shape the settings can produce must render. iOS 26.x/27 made
/// `CGPathAddRoundedRect` abort when a corner radius passes half its rect, and
/// full roundness did exactly that: the app died as soon as the user picked the
/// roundest modules ("21:00" typed, then the modules family — crash).
@MainActor
final class RendererRoundnessTests: XCTestCase {
    private let renderer = QRCodeRenderer()

    func testEveryShapeAndSizeRenders() {
        // 128 is where a long payload gives modules barely over a point across.
        for size in [CGFloat(128), 512] {
            for roundness in [CGFloat(0), 0.35, 0.999, 1] {
                for eyeStyle in QRCodeConfiguration.EyeStyle.allCases {
                    for eyeScale in [CGFloat(0.3), 1, 1.15] {
                        var config = QRCodeConfiguration()
                        config.roundness = roundness
                        config.eyeStyle = eyeStyle
                        config.eyeScale = eyeScale
                        let image = renderer.renderToCGImage(
                            input: QRInput(content: "21:00"),
                            configuration: config,
                            size: size,
                            captionText: nil
                        )
                        XCTAssertNotNil(image, "\(size) \(roundness) \(eyeStyle) \(eyeScale)")
                    }
                }
            }
        }
    }

    /// A long payload packs the matrix, so a module is a fraction of a point.
    func testDenseCodeAtFullRoundnessRenders() {
        var config = QRCodeConfiguration()
        config.roundness = 1
        config.eyeStyle = .dot
        let long = String(repeating: "https://radicalsolution.com/radical-qr ", count: 20)
        XCTAssertNotNil(renderer.renderToCGImage(
            input: QRInput(content: long), configuration: config, size: 128, captionText: nil
        ))
    }
}
