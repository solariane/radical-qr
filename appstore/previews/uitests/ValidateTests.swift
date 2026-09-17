import XCTest

final class ValidateTests: XCTestCase {
    @MainActor
    func testExamples() throws {
        let lang = ProcessInfo.processInfo.environment["DEMO_LANG"] ?? "en"
        let ex = examples[lang]!
        let app = launchApp(lang: lang)
        sleep(3)
        for (name, text) in [("event", ex.event), ("wifi", ex.wifi), ("signature", ex.signature), ("address", ex.address)] {
            paste(text)
            sleep(3)
            snap("v_\(lang)_\(name)")
            clearInput(app)
            sleep(2)
        }
    }
}
