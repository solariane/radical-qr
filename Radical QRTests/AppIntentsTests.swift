import XCTest
import SwiftData
@testable import Radical_QR

/// What Siri and Shortcuts hand the app becomes the same payload a paste would,
/// and the history they write follows the generator's rules.
@MainActor
final class AppIntentsTests: XCTestCase {
    // MARK: - Payload

    func testWiFiCardBecomesWiFiString() throws {
        let input = try QRIntentPayload.input(from: "Wi-Fi : Livebox-A1B2\nMot de passe : xK9#mQ2!")
        XCTAssertEqual(input.detectedType, .wifi)
        XCTAssertTrue(input.content.hasPrefix("WIFI:"))
        XCTAssertTrue(input.content.contains("S:Livebox-A1B2;"))
    }

    func testLinkStaysALink() throws {
        let input = try QRIntentPayload.input(from: "  https://radicalsolution.com/qr \n")
        XCTAssertEqual(input.detectedType, .url)
        XCTAssertEqual(input.content, "https://radicalsolution.com/qr")
    }

    func testProseStaysAsWritten() throws {
        let text = "Remember to bring the blue folder"
        let input = try QRIntentPayload.input(from: text)
        XCTAssertEqual(input.detectedType, .text)
        XCTAssertEqual(input.content, text)
    }

    func testEmptyContentIsRefused() {
        XCTAssertThrowsError(try QRIntentPayload.input(from: " \n ")) { error in
            guard case QRIntentError.emptyContent = error else {
                return XCTFail("Expected emptyContent, got \(error)")
            }
        }
    }

    func testSummaryNamesTheNetwork() throws {
        let input = try QRIntentPayload.input(from: "Wi-Fi : Livebox-A1B2\nMot de passe : xK9#mQ2!")
        XCTAssertTrue(QRIntentPayload.summary(for: input).contains("Livebox-A1B2"))
    }

    // MARK: - Create QR Code

    private func makeIntent(_ content: String, format: QRFormatOption = .png, size: Int = 512) -> CreateQRCodeIntent {
        var intent = CreateQRCodeIntent()
        intent.content = content
        intent.format = format
        intent.size = size
        return intent
    }

    private func withProState<T>(_ state: PurchaseManager.TestProOverride, _ body: () async throws -> T) async rethrows -> T {
        let manager = PurchaseManager.shared
        let saved = manager.testProOverride
        manager.testProOverride = state
        defer { manager.testProOverride = saved }
        return try await body()
    }

    func testFreeUserGetsAPNG() async throws {
        try await withProState(.forceFree) {
            _ = try await makeIntent("https://radicalsolution.com").perform()
        }
    }

    func testFreeUserCannotExportSVG() async {
        await withProState(.forceFree) {
            do {
                _ = try await makeIntent("https://radicalsolution.com", format: .svg).perform()
                XCTFail("SVG should need Pro")
            } catch QRIntentError.requiresPro {
            } catch {
                XCTFail("Expected requiresPro, got \(error)")
            }
        }
    }

    func testFreeUserCannotGoAbove512() async {
        await withProState(.forceFree) {
            do {
                _ = try await makeIntent("hello", size: 1024).perform()
                XCTFail("1024 px should need Pro")
            } catch QRIntentError.requiresPro {
            } catch {
                XCTFail("Expected requiresPro, got \(error)")
            }
        }
    }

    func testProUserGetsALargeSVG() async throws {
        try await withProState(.forcePro) {
            _ = try await makeIntent("Wi-Fi : Livebox\nMot de passe : secret123", format: .svg, size: 2048).perform()
        }
    }

    // MARK: - History

    func testRecordingTheSameContentTwiceKeepsOneItem() throws {
        let container = try ModelContainer(
            for: HistoryItem.self, StylePreset.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        let first = HistoryItem.record(content: "https://a.example", dataType: .url, configuration: .default, in: context)
        let second = HistoryItem.record(content: "https://a.example", dataType: .url, configuration: .default, in: context)

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(second.usageCount, 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HistoryItem>()), 1)
    }

    func testHistoryIsCapped() throws {
        let container = try ModelContainer(
            for: HistoryItem.self, StylePreset.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        for index in 0...FeatureLimit.maxHistoryItems {
            HistoryItem.record(content: "code \(index)", dataType: .text, configuration: .default, in: context)
        }

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HistoryItem>()), FeatureLimit.maxHistoryItems)
    }
}
