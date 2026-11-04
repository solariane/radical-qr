import XCTest
import CoreGraphics
@testable import Radical_QR

/// The ready-made swatches stay readable on any background colour, and the
/// code follows its swatch when the background changes.
final class ContrastPaletteTests: XCTestCase {
    private let hardBlue = SerializableColor(red: 0.05, green: 0.15, blue: 0.75)
    private let cream = SerializableColor(red: 1.0, green: 0.97, blue: 0.9)
    private let paleYellow = SerializableColor(red: 1.0, green: 0.93, blue: 0.4)
    private let darkGreen = SerializableColor(red: 0.05, green: 0.25, blue: 0.12)

    private let backgrounds: [SerializableColor] = [
        SerializableColor(red: 0.05, green: 0.15, blue: 0.75),
        SerializableColor(red: 1.0, green: 0.97, blue: 0.9),
        SerializableColor(red: 1.0, green: 0.93, blue: 0.4),
        SerializableColor(red: 0.05, green: 0.25, blue: 0.12),
        SerializableColor(red: 1, green: 0, blue: 0),
        SerializableColor(red: 0.5, green: 0.5, blue: 0.5),
        SerializableColor(red: 0, green: 0, blue: 0),
        SerializableColor(red: 0, green: 0.8, blue: 0.8),
    ]

    func testContrastMatchesWCAG() {
        XCTAssertEqual(ContrastPalette.contrast(.black, .white), 21, accuracy: 0.01)
        XCTAssertEqual(ContrastPalette.contrast(.white, .white), 1, accuracy: 0.001)
    }

    func testWhiteOrNoBackgroundKeepsTheFreePalette() {
        XCTAssertEqual(ContrastPalette.solids(on: nil), SerializableColor.freeColors)
        XCTAssertEqual(ContrastPalette.gradients(on: nil), GradientConfiguration.freeGradients)
    }

    func testEverySwatchIsReadableOnEveryBackground() {
        for bg in backgrounds {
            let solids = ContrastPalette.solids(on: bg)
            XCTAssertEqual(solids.count, 6)
            XCTAssertEqual(Set(solids).count, 6, "Swatches must stay distinct on \(bg)")
            for color in solids {
                XCTAssertGreaterThanOrEqual(ContrastPalette.contrast(color, bg), ContrastPalette.solidTarget - 0.01, "\(color) on \(bg)")
            }
            for gradient in ContrastPalette.gradients(on: bg) {
                XCTAssertGreaterThanOrEqual(ContrastPalette.contrast(gradient.startColor, bg), ContrastPalette.gradientTarget - 0.01)
                XCTAssertGreaterThanOrEqual(ContrastPalette.contrast(gradient.endColor, bg), ContrastPalette.gradientTarget - 0.01)
            }
        }
    }

    func testLightBackgroundKeepsFreeColorsThatAlreadyRead() {
        // Every free colour is dark: on cream they read as they are.
        XCTAssertEqual(ContrastPalette.solids(on: cream), SerializableColor.freeColors)
    }

    func testDarkBackgroundOffersWhiteAndLightColors() {
        let solids = ContrastPalette.solids(on: hardBlue)
        XCTAssertEqual(solids.first, .white)
        for color in solids {
            XCTAssertGreaterThan(ContrastPalette.luminance(color), ContrastPalette.luminance(hardBlue))
        }
        // The complement of a blue is a warm colour: more red than blue.
        let complement = solids[2]
        XCTAssertGreaterThan(complement.red, complement.blue)
    }

    func testCodeFollowsItsSwatchToTheNewBackground() {
        var config = QRCodeConfiguration()
        config.foregroundStyle = .solid(.navy)
        config.setBackground(.white, color: hardBlue)
        XCTAssertEqual(config.foregroundStyle, .solid(ContrastPalette.solids(on: hardBlue)[1]))
        XCTAssertEqual(config.backgroundFill, hardBlue)

        // Back to white: back to the original navy.
        config.setBackground(.white)
        XCTAssertEqual(config.foregroundStyle, .solid(.navy))
        XCTAssertNil(config.backgroundColor)
    }

    func testGradientKeepsItsTypeAndAngle() {
        var config = QRCodeConfiguration()
        var preset = GradientConfiguration.orangePink
        preset.type = .radial
        config.foregroundStyle = .gradient(preset)
        config.setBackground(.white, color: darkGreen)
        guard case .gradient(let moved) = config.foregroundStyle else { return XCTFail("Still a gradient") }
        XCTAssertEqual(moved.type, .radial)
        XCTAssertEqual(moved.startColor, ContrastPalette.gradients(on: darkGreen)[2].startColor)
    }

    func testReadableCustomColorIsLeftAlone() {
        var config = QRCodeConfiguration()
        let custom = SerializableColor(red: 0.3, green: 0.1, blue: 0.05)
        config.foregroundStyle = .solid(custom)
        config.setBackground(.white, color: paleYellow)
        XCTAssertEqual(config.foregroundStyle, .solid(custom))
    }

    func testUnreadableCustomColorIsMovedJustEnough() {
        var config = QRCodeConfiguration()
        let custom = SerializableColor(red: 0.1, green: 0.2, blue: 0.6)
        config.foregroundStyle = .solid(custom)
        config.setBackground(.white, color: hardBlue)
        guard case .solid(let moved) = config.foregroundStyle else { return XCTFail("Still solid") }
        XCTAssertNotEqual(moved, custom)
        XCTAssertNotEqual(moved, .white, "Moved along lightness, not replaced")
        XCTAssertGreaterThanOrEqual(ContrastPalette.contrast(moved, hardBlue), ContrastPalette.solidTarget - 0.01)
    }

    func testTransparentClearsTheColor() {
        var config = QRCodeConfiguration()
        config.setBackground(.white, color: cream)
        config.setBackground(.transparent)
        XCTAssertNil(config.backgroundColor)
        XCTAssertNil(config.backgroundFill)
    }

    func testOlderPayloadWithoutColorStillDecodes() throws {
        var config = QRCodeConfiguration()
        config.setBackground(.white, color: hardBlue)
        let data = try JSONEncoder().encode(config)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        // A payload written before the field existed.
        XCTAssertNotNil(json.removeValue(forKey: "backgroundColor"))
        let older = try JSONDecoder().decode(QRCodeConfiguration.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(older.foregroundStyle, config.foregroundStyle)
        XCTAssertEqual(older.backgroundFill, .white)

        let roundTrip = try JSONDecoder().decode(QRCodeConfiguration.self, from: data)
        XCTAssertEqual(roundTrip.backgroundColor, hardBlue)
    }
}
