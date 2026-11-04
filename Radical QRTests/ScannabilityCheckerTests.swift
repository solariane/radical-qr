import XCTest
import CoreGraphics
@testable import Radical_QR

/// On-device scannability check: a normal code reads, a pale/low-contrast one is flagged.
@MainActor
final class ScannabilityCheckerTests: XCTestCase {
    private let renderer = QRCodeRenderer()
    private let checker = ScannabilityChecker()

    private func render(_ configure: (inout QRCodeConfiguration) -> Void) -> CGImage {
        var config = QRCodeConfiguration()
        configure(&config)
        let cg = renderer.renderToCGImage(
            input: QRInput(content: "https://radicalsolution.com"),
            configuration: config,
            size: 512,
            captionText: nil
        )
        return cg!
    }

    func testPlainBlackCodeIsReliable() {
        let config = QRCodeConfiguration()   // default: black on white, square
        let img = render { $0 = config }
        let result = checker.check(cgImage: img, configuration: config)
        XCTAssertEqual(result.level, .reliable)
        XCTAssertNil(result.fix)
    }

    func testPaleForegroundOnWhiteIsRisky() {
        var config = QRCodeConfiguration()
        config.foregroundStyle = .solid(SerializableColor(red: 0.92, green: 0.92, blue: 0.6))
        config.backgroundType = .white
        let img = render { $0 = config }
        let result = checker.check(cgImage: img, configuration: config)
        // Pale-on-white either fails to decode or trips the contrast check → risky.
        XCTAssertEqual(result.level, .risky)
        XCTAssertNotNil(result.reason)
    }

    func testRiskyCodeAlwaysOffersAReasonOrFix() {
        var config = QRCodeConfiguration()
        config.foregroundStyle = .solid(SerializableColor(red: 0.95, green: 0.95, blue: 0.95))
        let img = render { $0 = config }
        let result = checker.check(cgImage: img, configuration: config)
        if result.level == .risky {
            XCTAssertTrue(result.reason != nil || result.fix != nil,
                          "A risky verdict must explain why or offer a fix")
        }
    }

    // MARK: - Background colour

    private let hardBlue = SerializableColor(red: 0.05, green: 0.15, blue: 0.75)

    func testDarkCodeOnCreamIsReliable() {
        var config = QRCodeConfiguration()
        config.setBackground(.white, color: SerializableColor(red: 1.0, green: 0.97, blue: 0.9))
        let result = checker.check(cgImage: render { $0 = config }, configuration: config)
        XCTAssertEqual(result.level, .reliable)
    }

    func testLightCodeOnDarkBackgroundDecodesButWarns() {
        var config = QRCodeConfiguration()
        config.setBackground(.white, color: hardBlue)   // black follows to white
        XCTAssertEqual(config.foregroundStyle, .solid(.white))
        let result = checker.check(cgImage: render { $0 = config }, configuration: config)
        XCTAssertEqual(result.level, .risky)
        XCTAssertNil(result.fix, "Inverted is a property of the design, not a fault to fix")
        XCTAssertNotNil(result.reason)     // a nil fix also means it decoded: failures always offer one
    }

    func testCodeTooCloseToTheBackgroundIsRisky() {
        var config = QRCodeConfiguration()
        config.backgroundColor = hardBlue                // set directly: no palette move
        config.foregroundStyle = .solid(.navy)
        let result = checker.check(cgImage: render { $0 = config }, configuration: config)
        XCTAssertEqual(result.level, .risky)
        XCTAssertNil(result.fix)
    }
}
