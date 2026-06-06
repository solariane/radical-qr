import XCTest
@testable import Radical_QR

/// Regression tests for SVG export: rounded/scaled eyes and the fit-to-width
/// caption option. These exercise the real ExportService end-to-end.
///
/// @MainActor because the app module uses default main-actor isolation, so the
/// model initializers (QRInput, QRCodeConfiguration) must be called on the main
/// actor.
@MainActor
final class ExportServiceSVGTests: XCTestCase {

    private func makeSVG(
        content: String = "https://example.com",
        configure: (inout QRCodeConfiguration) -> Void,
        caption: String? = nil
    ) async throws -> String {
        let input = QRInput(content: content)
        var config = QRCodeConfiguration()
        configure(&config)
        let data = try await ExportService().export(
            input: input,
            configuration: config,
            exportConfig: ExportConfiguration(format: .svg, size: .medium),
            captionText: caption
        )
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: - Bug: rounded eyes were lost on SVG export

    func testDotEyesEmitEvenOddArcPath() async throws {
        let svg = try await makeSVG { config in
            config.eyeStyle = .dot
            config.eyeScale = 1.0
        }
        // Eyes are drawn as a dedicated even-odd path...
        XCTAssertTrue(svg.contains("fill-rule=\"evenodd\""),
                      "Non-square eyes must be a separate even-odd path")
        // ...with smooth curves (arc commands) and geometricPrecision override.
        XCTAssertTrue(svg.contains("geometricPrecision"),
                      "Non-square eyes must override crispEdges")
        XCTAssertTrue(svg.contains("evenodd\" shape-rendering=\"geometricPrecision\" d=\"M"),
                      "Eyes path should carry the rounding attributes")
    }

    func testSquareEyesProduceEvenOddPathWithoutArcs() async throws {
        let svg = try await makeSVG { config in
            config.eyeStyle = .square
            config.eyeScale = 1.0
        }
        XCTAssertTrue(svg.contains("fill-rule=\"evenodd\""),
                      "Eyes are always a separate even-odd path")
        XCTAssertFalse(svg.contains("geometricPrecision"),
                       "Square eyes must not request geometricPrecision")
    }

    func testLeafEyeProducesArcsAndDiffersFromDot() async throws {
        let leaf = try await makeSVG { $0.eyeStyle = .leaf }
        let dot = try await makeSVG { $0.eyeStyle = .dot }
        XCTAssertTrue(leaf.contains("geometricPrecision"), "Leaf eyes are non-square")
        XCTAssertTrue(leaf.contains("0 0 1"), "Leaf eyes use elliptical-arc commands for rounded corners")
        func eyesPath(_ svg: String) -> String? {
            guard let r = svg.range(of: "fill-rule=\"evenodd\"") else { return nil }
            return String(svg[r.upperBound...].prefix(260))
        }
        XCTAssertNotEqual(eyesPath(leaf), eyesPath(dot),
                          "Leaf (3 rounded + 1 sharp corner) must differ from dot")
    }

    func testEyeScaleChangesEyesPath() async throws {
        let full = try await makeSVG { $0.eyeScale = 1.0 }
        let shrunk = try await makeSVG { $0.eyeScale = 0.6 }
        // Scaling the eyes must change the generated geometry.
        func eyesPath(_ svg: String) -> Substring? {
            guard let r = svg.range(of: "fill-rule=\"evenodd\"") else { return nil }
            return svg[r.upperBound...].prefix(200)
        }
        XCTAssertNotEqual(eyesPath(full).map(String.init),
                          eyesPath(shrunk).map(String.init),
                          "eyeScale must affect the eyes path")
    }

    // MARK: - Feature: fit-to-width caption

    func testFitToWidthAddsTextLengthForLongCaption() async throws {
        let longCaption = String(repeating: "VeryLongCaption ", count: 8)
        let svg = try await makeSVG(configure: { config in
            config.showCaption = true
            config.captionFitToWidth = true
        }, caption: longCaption)
        XCTAssertTrue(svg.contains("textLength="),
                      "An overflowing fit-to-width caption must set textLength")
        XCTAssertTrue(svg.contains("lengthAdjust=\"spacingAndGlyphs\""),
                      "Fit-to-width caption must use spacingAndGlyphs")
    }

    func testNonFitCaptionHasNoTextLength() async throws {
        let longCaption = String(repeating: "VeryLongCaption ", count: 8)
        let svg = try await makeSVG(configure: { config in
            config.showCaption = true
            config.captionFitToWidth = false
        }, caption: longCaption)
        XCTAssertFalse(svg.contains("textLength="),
                       "Without fit-to-width, the caption must not be constrained")
    }

    func testShortFitCaptionIsNotStretched() async throws {
        let svg = try await makeSVG(configure: { config in
            config.showCaption = true
            config.captionFitToWidth = true
        }, caption: "OK")
        // A short caption already fits, so no textLength should be applied
        // (fit-to-width shrinks overflow, it never stretches short text).
        XCTAssertFalse(svg.contains("textLength="),
                       "Short captions must not be stretched to full width")
    }
}
