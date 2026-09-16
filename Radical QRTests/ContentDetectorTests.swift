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
        // WPA with an empty password: the form keeps the password field to fill in.
        XCTAssertEqual(detection.draft, .wifi(WiFiDraft(ssid: "Café du Coin", security: .wpa)))
    }

    func testWrittenWiFiLabelIsNotTheWiFiFormat() throws {
        XCTAssertEqual(DataTypeDetector.detect("WIFI:T:WPA;S:Home;P:x;;"), .wifi)
        XCTAssertEqual(DataTypeDetector.detect("WIFI:S:Home;;"), .wifi)
        XCTAssertEqual(DataTypeDetector.detect("Wifi: Livebox"), .text)
        let detection = try XCTUnwrap(detect("Wifi: Livebox-A1B2\nMot de passe : xK9#mQ2!"))
        XCTAssertEqual(detection.draft, .wifi(WiFiDraft(ssid: "Livebox-A1B2", password: "xK9#mQ2!")))
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

    // MARK: - Place

    func testAddressAloneIsAPlace() throws {
        let detection = try XCTUnwrap(detect("12 rue de Rivoli\n75001 Paris"))
        XCTAssertEqual(detection.confidence, .high)
        XCTAssertEqual(detection.draft, .place(PlaceDraft(address: "12 rue de Rivoli, 75001 Paris")))
    }

    func testStreetWithoutTownIsOnlySuggested() throws {
        let detection = try XCTUnwrap(detect("10 rue de la Paix"))
        XCTAssertEqual(detection.confidence, .medium)
    }

    func testSentenceMentioningAnAddressIsNotAPlace() {
        XCTAssertNil(detect("Je t'attendrai devant l'entrée principale du 12 rue de Rivoli, pas de retard"))
    }

    func testAddressWithPhoneIsACard() throws {
        let detection = try XCTUnwrap(detect("Boulangerie Martin\n12 rue de Rivoli, 75001 Paris\n01 23 45 67 89"))
        guard case .contact = detection.draft else { return XCTFail("expected a contact") }
    }

    func testMapsLinkRoundTrip() throws {
        let draft = PlaceDraft(address: "5 place de la République, 69002 Lyon")
        XCTAssertEqual(draft.mapsURL, "https://maps.apple.com/?address=5%20place%20de%20la%20R%C3%A9publique,%2069002%20Lyon")
        XCTAssertEqual(PlaceDraft(mapsURL: draft.mapsURL), draft)
        XCTAssertEqual(DataTypeDetector.detect(draft.mapsURL), .url)
        XCTAssertEqual(ContentDraft(content: draft.mapsURL, type: .url), .place(draft))
        // Coordinates or a search keep their own meaning.
        XCTAssertNil(PlaceDraft(mapsURL: "https://maps.apple.com/?ll=48.86,2.35&q=Louvre"))
        XCTAssertNil(ContentDraft(content: "https://example.com/?address=x", type: .url))
    }

    // MARK: - Precedence

    func testAppointmentStaysAnEvent() throws {
        let detection = try XCTUnwrap(detect("Dîner chez Marie 19/09/2099 20h"))
        guard case .event = detection.draft else { return XCTFail("expected an event") }
    }
}
