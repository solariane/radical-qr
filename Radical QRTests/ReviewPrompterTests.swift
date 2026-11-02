import XCTest
@testable import Radical_QR

/// When the review prompt may be asked: counted on the device, put off by friction.
@MainActor
final class ReviewPrompterTests: XCTestCase {
    /// A fresh store and clock per test: no shared state, no setUp.
    @MainActor
    private final class Fixture {
        let defaults: UserDefaults
        var date = Date(timeIntervalSince1970: 1_800_000_000)

        init() {
            let suite = "ReviewPrompterTests-\(UUID().uuidString)"
            defaults = UserDefaults(suiteName: suite)!
        }

        func advance(days: Int) { date = date.addingTimeInterval(TimeInterval(days) * 86_400) }

        func prompter(version: String = "2.1.4") -> ReviewPrompter {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "UTC")!
            return ReviewPrompter(
                rules: .init(minimumMoments: 3, minimumActiveDays: 2, minimumDaysSinceFirstUse: 3),
                defaults: defaults,
                version: version,
                calendar: calendar,
                now: { self.date }
            )
        }
    }

    /// Three moments over two days, then three days after the first.
    private func becomeDue(_ prompter: ReviewPrompter, _ fixture: Fixture) {
        prompter.recordValueMoment()
        prompter.recordValueMoment()
        fixture.advance(days: 1)
        prompter.recordValueMoment()
        fixture.advance(days: 2)
    }

    func testNotDueOnFirstUse() {
        let fixture = Fixture()
        let prompter = fixture.prompter()
        prompter.recordValueMoment()
        XCTAssertFalse(prompter.isDue)
    }

    func testDueAfterRepeatedUseOnSeveralDays() {
        let fixture = Fixture()
        let prompter = fixture.prompter()
        becomeDue(prompter, fixture)
        XCTAssertTrue(prompter.isDue)
    }

    func testMomentsOnOneDayCountAsOneActiveDay() {
        let fixture = Fixture()
        let prompter = fixture.prompter()
        for _ in 0..<5 { prompter.recordValueMoment() }
        fixture.advance(days: 10)
        XCTAssertFalse(prompter.isDue)
    }

    func testWaitsForDaysSinceFirstUse() {
        let fixture = Fixture()
        let prompter = fixture.prompter()
        prompter.recordValueMoment()
        prompter.recordValueMoment()
        fixture.advance(days: 1)
        prompter.recordValueMoment()
        XCTAssertFalse(prompter.isDue)
    }

    func testFrictionPutsTheAskOffForTheSession() {
        let fixture = Fixture()
        let prompter = fixture.prompter()
        becomeDue(prompter, fixture)
        prompter.recordFriction()
        XCTAssertFalse(prompter.isDue)

        // A new launch reads the same counters without the friction.
        XCTAssertTrue(fixture.prompter().isDue)
    }

    func testRequestIfDueAsksOncePerVersion() {
        let fixture = Fixture()
        let prompter = fixture.prompter()
        becomeDue(prompter, fixture)

        var asks = 0
        prompter.requestIfDue { asks += 1 }
        prompter.requestIfDue { asks += 1 }
        XCTAssertEqual(asks, 1)
        XCTAssertFalse(prompter.isDue)
    }

    func testRequestIfDueDoesNothingWhenNotDue() {
        var asks = 0
        Fixture().prompter().requestIfDue { asks += 1 }
        XCTAssertEqual(asks, 0)
    }

    func testANewVersionStillWaitsBetweenAsks() {
        let fixture = Fixture()
        becomeDue(fixture.prompter(), fixture)
        fixture.prompter().requestIfDue {}

        fixture.advance(days: 30)
        XCTAssertFalse(fixture.prompter(version: "2.2").isDue)

        fixture.advance(days: 90)
        XCTAssertTrue(fixture.prompter(version: "2.2").isDue)
    }
}
