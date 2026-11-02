import XCTest
@testable import Radical_QR

/// The name the save panel proposes: what the code holds, then the size.
final class ExportFileNameTests: XCTestCase {
    private func name(_ content: String, _ type: DataType, width: Int = 512) -> String {
        ExportFileName.baseName(for: QRInput(content: content, detectedType: type), width: width)
    }

    func testLinkGivesItsSite() {
        XCTAssertEqual(name("https://www.me.com/path?x=1", .url), "qrcode-me.com-512px")
        XCTAssertEqual(name("radicalsolution.com", .url, width: 4096), "qrcode-radicalsolution.com-4096px")
    }

    func testWiFiGivesItsNetwork() {
        XCTAssertEqual(name("WIFI:T:WPA;S:Ma Box;P:secret;;", .wifi), "qrcode-wifi-ma-box-512px")
    }

    func testContactGivesItsName() {
        let card = "BEGIN:VCARD\nVERSION:3.0\nFN:Jean Dupont\nTEL:+33612345678\nEND:VCARD"
        XCTAssertEqual(name(card, .vcard), "qrcode-jean-dupont-512px")
    }

    func testEventGivesItsTitleWithoutAccents() {
        let event = "BEGIN:VEVENT\nSUMMARY:Réunion d'équipe\nDTSTART:20261116T090000Z\nDTEND:20261116T100000Z\nEND:VEVENT"
        XCTAssertEqual(name(event, .icalendar), "qrcode-reunion-d-equipe-512px")
    }

    func testEmailAndPhoneDropTheirScheme() {
        XCTAssertEqual(name("mailto:jean@me.com?subject=Hi", .email), "qrcode-jean-me.com-512px")
        XCTAssertEqual(name("tel:+33 6 12 34 56 78", .phone), "qrcode-33-6-12-34-56-78-512px")
    }

    func testTextKeepsItsFirstWords() {
        XCTAssertEqual(name("Bonjour à tous, voici le menu du jour", .text), "qrcode-bonjour-a-tous-voici-512px")
    }

    func testOtherScriptsStay() {
        XCTAssertEqual(name("こんにちは 世界", .text), "qrcode-こんにちは-世界-512px")
    }

    func testLongContentIsCut() {
        let long = String(repeating: "abcdefghij", count: 10)
        let words = ExportFileName.slug(long) ?? ""
        XCTAssertEqual(words.count, ExportFileName.maxLength)
    }

    func testNothingToSayFallsBackToTheSize() {
        XCTAssertEqual(name("geo:48.85,2.35", .geo), "qrcode-512px")
        XCTAssertEqual(name("!!!", .text), "qrcode-512px")
        XCTAssertEqual(ExportFileName.baseName(for: nil, width: 256), "qrcode-256px")
    }
}
