import XCTest
@testable import Radical_QR

/// Free text that reads as an appointment becomes an event draft; prose does not.
/// Inputs avoid "demain"/"today": NSDataDetector resolves those against the real
/// clock, which a test cannot pin.
@MainActor
final class EventDetectorTests: XCTestCase {
    /// Most dates below are day/month and far enough ahead to stay future for a while.
    private let now = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 10))!

    private func components(_ date: Date) -> DateComponents {
        Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    }

    // MARK: - Confidence

    func testDayAndTimeIsHighConfidenceWithEmptyTitle() throws {
        let detection = try XCTUnwrap(EventDetector.detect(in: "21h mercredi 16/09/2099", now: now))
        XCTAssertEqual(detection.confidence, .high)
        XCTAssertEqual(detection.draft.title, "")
        XCTAssertFalse(detection.draft.isAllDay)
        let start = components(detection.draft.start)
        XCTAssertEqual([start.day, start.month, start.hour], [16, 9, 21])
        XCTAssertEqual(detection.draft.end.timeIntervalSince(detection.draft.start), EventDraft.defaultDuration)
    }

    func testRemainingTextBecomesTheTitle() throws {
        let detection = try XCTUnwrap(EventDetector.detect(in: "Anniversaire de Marie le 19/09/2099 à 19h30", now: now))
        XCTAssertEqual(detection.confidence, .high)
        XCTAssertEqual(detection.draft.title, "Anniversaire de Marie")
    }

    func testLinkIsLiftedOutOfTheTitle() throws {
        let detection = try XCTUnwrap(
            EventDetector.detect(in: "Réunion 16/09/2099 9h30 https://meet.google.com/abc", now: now)
        )
        XCTAssertEqual(detection.draft.title, "Réunion")
        XCTAssertEqual(detection.draft.url, "https://meet.google.com/abc")
    }

    func testTimeRangeSetsTheEnd() throws {
        let detection = try XCTUnwrap(EventDetector.detect(in: "16/09/2099 21h-23h", now: now))
        XCTAssertEqual(detection.draft.end.timeIntervalSince(detection.draft.start), 2 * 3600)
    }

    func testDateWithoutTimeIsAllDayAndOnlySuggested() throws {
        let detection = try XCTUnwrap(EventDetector.detect(in: "16/09/2099", now: now))
        XCTAssertEqual(detection.confidence, .medium)
        XCTAssertTrue(detection.draft.isAllDay)
        XCTAssertEqual(components(detection.draft.start).hour, 0)
    }

    func testExplicitNoonIsNotAllDay() throws {
        let detection = try XCTUnwrap(EventDetector.detect(in: "16/09/2099 12h", now: now))
        XCTAssertFalse(detection.draft.isAllDay)
    }

    func testTwoDatesAreOnlySuggested() throws {
        let detection = try XCTUnwrap(EventDetector.detect(in: "Du 16/09/2099 21h, reporté au 18/09/2099 21h", now: now))
        XCTAssertEqual(detection.confidence, .medium)
    }

    // MARK: - Address

    func testAddressBecomesTheLocation() throws {
        let detection = try XCTUnwrap(
            EventDetector.detect(in: "rdv lundi 10h chez Paul, 12 rue de Rivoli 75001 Paris", now: now)
        )
        XCTAssertEqual(detection.draft.location, "12 rue de Rivoli 75001 Paris")
        XCTAssertEqual(detection.draft.title, "rdv chez Paul")
    }

    func testMultilineAddressIsJoinedAndDoesNotCountAsProse() throws {
        let detection = try XCTUnwrap(
            EventDetector.detect(in: "Dîner chez Marie\n12 rue de Rivoli\n75001 Paris\nsamedi 20h", now: now)
        )
        XCTAssertEqual(detection.draft.location, "12 rue de Rivoli, 75001 Paris")
        XCTAssertEqual(detection.draft.title, "Dîner chez Marie")
        XCTAssertEqual(detection.confidence, .high)
    }

    func testWeekdayTakenByTheAddressGoesBackToTheDate() throws {
        let detection = try XCTUnwrap(
            EventDetector.detect(in: "Dinner at 221B Baker Street, London Friday 8pm", now: now)
        )
        XCTAssertEqual(detection.draft.location, "221B Baker Street, London")
        XCTAssertEqual(detection.draft.title, "Dinner")
        let start = Calendar.current.dateComponents([.weekday, .hour], from: detection.draft.start)
        XCTAssertEqual([start.weekday, start.hour], [6, 20])
    }

    func testAddressAfterTheDate() throws {
        let detection = try XCTUnwrap(
            EventDetector.detect(in: "Apéro 16/09/2099 19h au 5 place de la République, Lyon", now: now)
        )
        XCTAssertEqual(detection.draft.location, "5 place de la République, Lyon")
        XCTAssertEqual(detection.draft.title, "Apéro")
    }

    func testHouseNumberIsNotReadAsMinutes() throws {
        let detection = try XCTUnwrap(EventDetector.detect(in: "16/09/2099 21h 10 rue de la Paix", now: now))
        XCTAssertEqual(detection.draft.location, "10 rue de la Paix")
        XCTAssertEqual(Calendar.current.dateComponents([.hour, .minute], from: detection.draft.start).minute, 0)
        // Without a street after it, "21h 10" is ten past nine.
        let plain = try XCTUnwrap(EventDetector.detect(in: "16/09/2099 21h 10", now: now))
        XCTAssertEqual(Calendar.current.dateComponents([.minute], from: plain.draft.start).minute, 10)
    }

    func testSpanishAddressAndGlueWord() throws {
        let detection = try XCTUnwrap(
            EventDetector.detect(in: "Cena en Calle de Alcalá 42, 28014 Madrid viernes 21:00", now: now)
        )
        XCTAssertEqual(detection.draft.title, "Cena")
        XCTAssertEqual(detection.draft.location, "Calle de Alcalá 42, 28014 Madrid")
    }

    func testMealStaysInTheTitleAndTheTimeIsKept() throws {
        // The detector reads "dîner"/"Dinner" as a time of day; hour and title must survive it.
        for (text, title, location) in [
            ("dîner samedi 20h, 12 rue de Rivoli", "dîner", "12 rue de Rivoli"),
            ("Dinner Saturday 8pm, 350 Fifth Avenue, New York", "Dinner", "350 Fifth Avenue, New York")
        ] {
            let detection = try XCTUnwrap(EventDetector.detect(in: text, now: now), text)
            XCTAssertEqual(detection.draft.title, title, text)
            XCTAssertEqual(detection.draft.location, location, text)
            XCTAssertEqual(Calendar.current.component(.hour, from: detection.draft.start), 20, text)
            XCTAssertFalse(detection.draft.isAllDay, text)
        }
    }

    func testFullWidthAndArabicPunctuation() throws {
        // "、", "，" and "،" are commas too: out of the title, and not in the way of the address.
        for (text, title) in [
            ("ディナー 9月19日 20時、350 Fifth Avenue, New York", "ディナー"),
            ("晚餐 9月19日 20点，350 Fifth Avenue, New York", "晚餐"),
            ("عشاء 19/09 20:00، 350 Fifth Avenue, New York", "عشاء"),
        ] {
            let detection = try XCTUnwrap(EventDetector.detect(in: text, now: now), text)
            XCTAssertEqual(detection.draft.title, title, text)
            XCTAssertEqual(detection.draft.location, "350 Fifth Avenue, New York", text)
        }
    }

    func testNoAddressLeavesTheLocationEmpty() throws {
        let detection = try XCTUnwrap(EventDetector.detect(in: "Réunion salle 3 bâtiment B 16/09/2099 10h", now: now))
        XCTAssertEqual(detection.draft.location, "")
        XCTAssertEqual(detection.draft.title, "Réunion salle 3 bâtiment B")
    }

    // MARK: - Not events

    func testProseWithoutDigitsIsIgnored() {
        XCTAssertNil(EventDetector.detect(in: "Merci pour hier", now: now))
    }

    func testPlainTextIsIgnored() {
        XCTAssertNil(EventDetector.detect(in: "Radical QR", now: now))
        XCTAssertNil(EventDetector.detect(in: "version 2.0", now: now))
    }

    func testPhoneNumberIsNotAnEvent() {
        XCTAssertNil(EventDetector.detect(in: "+33 6 12 34 56 78", requireFullCoverage: true, now: now))
    }

    // MARK: - 年月日

    func testJapaneseDate() throws {
        let detection = try XCTUnwrap(EventDetector.detect(in: "会議 2099年9月16日 午後9時", now: now))
        XCTAssertEqual(detection.confidence, .high)
        XCTAssertEqual(detection.draft.title, "会議")
        let start = components(detection.draft.start)
        XCTAssertEqual([start.year, start.month, start.day, start.hour], [2099, 9, 16, 21])
    }

    func testChineseDateWithHalfHour() throws {
        let detection = try XCTUnwrap(EventDetector.detect(in: "9月16日 下午3点半", now: now))
        let start = components(detection.draft.start)
        XCTAssertEqual([start.month, start.day, start.hour, start.minute], [9, 16, 15, 30])
    }

    // MARK: - iCalendar round trip

    func testDraftRoundTripsThroughICalendar() throws {
        let start = Date(timeIntervalSince1970: 4_000_000_000)
        let draft = EventDraft(
            title: "Dîner; chez Paul, Marie",
            start: start,
            end: start.addingTimeInterval(5400),
            location: "12 rue de Rivoli",
            url: "https://example.com"
        )
        let ical = draft.icalendar
        XCTAssertTrue(ical.contains("SUMMARY:Dîner\\; chez Paul\\, Marie"))
        XCTAssertTrue(ical.contains("DTSTART:"), ical)
        XCTAssertTrue(ical.hasSuffix("Z\r\nLOCATION:12 rue de Rivoli\r\nURL:https://example.com\r\nEND:VEVENT"))
        XCTAssertEqual(EventDraft(icalendar: ical), draft)
        XCTAssertEqual(DataTypeDetector.detect(ical), .icalendar)
    }

    func testAllDayEndIsExclusiveInICalendar() throws {
        let day = Calendar.current.date(from: DateComponents(year: 2099, month: 9, day: 16))!
        let draft = EventDraft(start: day, end: day, isAllDay: true)
        XCTAssertTrue(draft.icalendar.contains("DTSTART;VALUE=DATE:20990916"))
        XCTAssertTrue(draft.icalendar.contains("DTEND;VALUE=DATE:20990917"))
        XCTAssertEqual(EventDraft(icalendar: draft.icalendar), draft)
    }

    func testRicherEventIsNotEditable() {
        let ical = "BEGIN:VEVENT\r\nSUMMARY:Weekly\r\nDTSTART:20990916T190000Z\r\nRRULE:FREQ=WEEKLY\r\nEND:VEVENT"
        XCTAssertNil(EventDraft(icalendar: ical))
    }
}

/// The generator's side: a paste switches to the editor, typing only suggests,
/// and "Keep as text" puts the pasted text back for good.
@MainActor
final class GeneratorEventFlowTests: XCTestCase {
    private func settle() async {
        try? await Task.sleep(for: .milliseconds(800))
    }

    func testPastedAppointmentBecomesAnEvent() async {
        let viewModel = GeneratorViewModel()
        viewModel.inputText = "21h mercredi 16/09/2099"
        await settle()

        XCTAssertNotNil(viewModel.draft)
        XCTAssertEqual(viewModel.editorRequest, 1)
        XCTAssertTrue(viewModel.inputText.hasPrefix("BEGIN:VEVENT"))
        XCTAssertEqual(viewModel.detectedDataType, .icalendar)

        guard case .event(var draft)? = viewModel.draft else { return XCTFail("not an event") }
        draft.title = "Dîner"
        viewModel.updateDraft(.event(draft))
        await settle()
        XCTAssertTrue(viewModel.inputText.contains("SUMMARY:Dîner"))
        XCTAssertEqual(viewModel.draft, .event(draft))

        viewModel.keepAsText()
        await settle()
        XCTAssertNil(viewModel.draft)
        XCTAssertNil(viewModel.suggestion)
        XCTAssertEqual(viewModel.inputText, "21h mercredi 16/09/2099")
    }

    func testBareDateIsOnlySuggested() async {
        let viewModel = GeneratorViewModel()
        viewModel.inputText = "16/09/2099"
        await settle()

        XCTAssertNil(viewModel.draft)
        XCTAssertNotNil(viewModel.suggestion)
        XCTAssertEqual(viewModel.inputText, "16/09/2099")

        viewModel.acceptSuggestion()
        XCTAssertNotNil(viewModel.draft)
        XCTAssertTrue(viewModel.inputText.contains("DTSTART;VALUE=DATE:20990916"))
    }

    func testTypingKeepsTheTextField() async {
        let viewModel = GeneratorViewModel()
        for character in "Wifi: Livebox" {
            viewModel.inputText.append(character)
            await Task.yield()
            // The field must never be swapped for a summary or a form mid-word.
            XCTAssertNil(viewModel.inputSummaryOverride, "after \(viewModel.inputText)")
            XCTAssertNil(viewModel.draft, "after \(viewModel.inputText)")
        }
        await settle()
        XCTAssertEqual(viewModel.suggestion, .wifi(WiFiDraft(ssid: "Livebox", security: .wpa)))
        viewModel.acceptSuggestion()
        XCTAssertNotNil(viewModel.inputSummaryOverride, "the form's content is summarised, not shown raw")

        // Typing the WIFI: format by hand keeps the field too.
        let raw = GeneratorViewModel()
        for character in "WIFI:S:Home;P:secret;;" {
            raw.inputText.append(character)
            await Task.yield()
            XCTAssertNil(raw.inputSummaryOverride, "after \(raw.inputText)")
            XCTAssertNil(raw.draft, "after \(raw.inputText)")
        }
    }

    func testPastedWiFiFormatOpensItsForm() async {
        let viewModel = GeneratorViewModel()
        viewModel.inputText = "WIFI:T:WPA;S:Home;P:secret;;"
        XCTAssertEqual(viewModel.draft, .wifi(WiFiDraft(ssid: "Home", password: "secret")))
    }

    func testTypedAppointmentIsOnlySuggested() async {
        let viewModel = GeneratorViewModel()
        for character in "21h mercredi 16/09/2099" {
            viewModel.inputText.append(character)
            await Task.yield()
        }
        await settle()

        XCTAssertNil(viewModel.draft)
        XCTAssertNotNil(viewModel.suggestion)
    }
}
