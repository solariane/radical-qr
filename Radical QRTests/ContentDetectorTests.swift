import XCTest
@testable import Radical_QR

/// Wi-Fi details and contact cards written for people become forms; prose with a
/// number in it does not.
final class ContentDetectorTests: XCTestCase {
    private func detect(_ text: String) -> ContentDetection? {
        ContentDetector.detect(in: text, type: DataTypeDetector.detect(text))
    }

    // MARK: - Wi-Fi

    func testFrenchWiFiCard() throws {
        let detection = try XCTUnwrap(detect("Wi-Fi : Livebox-A1B2\nMot de passe : xK9#mQ2!"))
        XCTAssertEqual(detection.confidence, .high)
        XCTAssertEqual(detection.draft, .wifi(WiFiDraft(ssid: "Livebox-A1B2", password: "xK9#mQ2!")))
    }

    func testSameLineLabelsAndSeparator() throws {
        let detection = try XCTUnwrap(detect("SSID: CafeGuest / Password: welcome2024"))
        XCTAssertEqual(detection.draft, .wifi(WiFiDraft(ssid: "CafeGuest", password: "welcome2024")))
    }

    func testPasswordKeepsItsTrailingDash() throws {
        let detection = try XCTUnwrap(detect("WLAN: FritzBox 7590\nPasswort: 1234-5678-"))
        XCTAssertEqual(detection.draft, .wifi(WiFiDraft(ssid: "FritzBox 7590", password: "1234-5678-")))
    }

    func testNetworkWithoutPasswordIsOnlySuggested() throws {
        let detection = try XCTUnwrap(detect("Réseau : Café du Coin"))
        XCTAssertEqual(detection.confidence, .medium)
        XCTAssertEqual(detection.draft, .wifi(WiFiDraft(ssid: "Café du Coin", security: WiFiDraft.Security.none)))
    }

    func testPasswordAloneIsNotANetwork() {
        XCTAssertNil(detect("Mot de passe : hunter2"))
    }

    func testWiFiStringRoundTripsWithEscapes() throws {
        let draft = WiFiDraft(ssid: "Chez \"Paul\"; 2.4", password: "a:b,c\\d", isHidden: true)
        XCTAssertEqual(draft.wifiString, #"WIFI:T:WPA;S:Chez \"Paul\"\; 2.4;P:a\:b\,c\\d;H:true;;"#)
        XCTAssertEqual(WiFiDraft(wifiString: draft.wifiString), draft)
        XCTAssertEqual(DataTypeDetector.detect(draft.wifiString), .wifi)
        XCTAssertEqual(WiFiDraft(wifiString: "WIFI:T:nopass;S:Open;;"), WiFiDraft(ssid: "Open"))
    }

    func testEnterpriseWiFiIsNotEditable() {
        XCTAssertNil(WiFiDraft(wifiString: "WIFI:T:WPA2-EAP;S:Corp;E:PEAP;I:me;P:x;;"))
    }

    // MARK: - Contact

    func testSignatureBlock() throws {
        let text = """
        Marie Dupont – Directrice artistique
        Studio Lumière
        +33 6 12 34 56 78 | marie@studio-lumiere.fr
        www.studio-lumiere.fr
        12 rue de Rivoli, 75001 Paris
        """
        let detection = try XCTUnwrap(detect(text))
        XCTAssertEqual(detection.confidence, .high)
        XCTAssertEqual(detection.draft, .contact(ContactDraft(
            name: "Marie Dupont", organization: "Studio Lumière", jobTitle: "Directrice artistique",
            phone: "+33 6 12 34 56 78", email: "marie@studio-lumiere.fr",
            website: "https://www.studio-lumiere.fr", address: "12 rue de Rivoli, 75001 Paris"
        )))
    }

    func testSingleLineCard() throws {
        let detection = try XCTUnwrap(detect("John Smith, (415) 555-0132, john@acme.com"))
        XCTAssertEqual(detection.confidence, .high)
        XCTAssertEqual(detection.draft, .contact(ContactDraft(name: "John Smith", phone: "(415) 555-0132", email: "john@acme.com")))
    }

    func testNameWithoutCapitals() throws {
        let detection = try XCTUnwrap(detect("山田太郎\n090-1234-5678\ntaro@example.jp"))
        guard case .contact(let contact) = detection.draft else { return XCTFail("not a contact") }
        XCTAssertEqual(contact.name, "山田太郎")
    }

    func testLabelsAreNotACompany() throws {
        let detection = try XCTUnwrap(detect("Tel: 01 23 45 67 89 / Email: contact@boulangerie.fr"))
        XCTAssertEqual(detection.confidence, .medium)
        XCTAssertEqual(detection.draft, .contact(ContactDraft(phone: "01 23 45 67 89", email: "contact@boulangerie.fr")))
    }

    func testTelLabelIsNotATelLink() {
        XCTAssertEqual(DataTypeDetector.detect("tel:+33612345678"), .phone)
        XCTAssertEqual(DataTypeDetector.detect("Tel: 01 23 45 67 89"), .phone)
        XCTAssertEqual(DataTypeDetector.detect("Tel: 01 23 45 67 89 / Email: contact@boulangerie.fr"), .text)
    }

    func testProseAroundANumberIsNotACard() {
        XCTAssertNil(detect("Merci, rappelle-moi au 06 12 34 56 78"))
    }

    func testLonePhoneAndEmailKeepTheirTypes() {
        XCTAssertNil(detect("06 12 34 56 78"))
        XCTAssertNil(detect("marie@example.com"))
    }

    func testVCardRoundTrip() throws {
        let draft = ContactDraft(
            name: "Anne de la Tour", organization: "Tour, Fils & Cie", jobTitle: "Gérante",
            phone: "+33 1 23 45 67 89", email: "anne@tour.fr", website: "https://tour.fr",
            address: "5 place de la République, Lyon"
        )
        let card = draft.vCard
        XCTAssertTrue(card.contains("N:Tour;Anne de la;;;"))
        XCTAssertTrue(card.contains("ORG:Tour\\, Fils & Cie"))
        XCTAssertEqual(ContactDraft(vCard: card), draft)
        XCTAssertEqual(DataTypeDetector.detect(card), .vcard)
    }

    func testRichVCardIsNotEditable() {
        let card = "BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Marie\r\nTEL;TYPE=CELL:1\r\nTEL;TYPE=WORK:2\r\nEND:VCARD"
        XCTAssertNil(ContactDraft(vCard: card))
    }

    // MARK: - Precedence

    func testAppointmentStaysAnEvent() throws {
        let detection = try XCTUnwrap(detect("Dîner chez Marie 19/09/2099 20h"))
        guard case .event = detection.draft else { return XCTFail("expected an event") }
    }
}
