import XCTest

/// Drives the two App Preview storyboards. Every visible action is preceded by
/// a mark "<beat>"; the edit keeps the first recorded frame after each mark
/// plus a hold, so the time XCTest spends between actions never reaches the cut.
final class StoryboardTests: XCTestCase {
    var lang: String { ProcessInfo.processInfo.environment["DEMO_LANG"] ?? "en" }

    @MainActor func hold(_ s: Double) { usleep(useconds_t(s * 1_000_000)) }

    /// Tiles of the family panel under the rail, grouped into rows top to bottom.
    @MainActor func panelRows(_ app: XCUIApplication) -> [[XCUIElement]] {
        let rail = app.buttons["paintpalette"].frame
        let tiles = app.buttons.allElementsBoundByIndex.filter {
            let f = $0.frame
            return f.minY > rail.maxY + 4 && f.width <= 100 && f.height >= 40 && f.height <= 64
        }
        var rows: [[XCUIElement]] = []
        for t in tiles.sorted(by: { $0.frame.midY < $1.frame.midY }) {
            if let last = rows.last?.first, abs(last.frame.midY - t.frame.midY) < 12 { rows[rows.count - 1].append(t) }
            else { rows.append([t]) }
        }
        return rows.map { $0.sorted { $0.frame.midX < $1.frame.midX } }
    }

    @MainActor func tapTile(_ app: XCUIApplication, row: Int, index: Int, beat: String) {
        var rows = panelRows(app)
        if rows.count <= row || rows[row].count <= index || rows[row][index].frame.maxY > 840 {
            app.scrollViews.firstMatch.swipeUp(velocity: .slow)
            hold(1.0)
            rows = panelRows(app)
        }
        guard rows.count > row, rows[row].count > index else { mark("MISSING \(beat)"); return }
        let tile = rows[row][index]
        mark(beat)
        tile.tap()
    }

    @MainActor func tapRail(_ app: XCUIApplication, _ id: String, beat: String) {
        let b = app.buttons[id]
        _ = b.waitForExistence(timeout: 10)
        mark(beat)
        b.tap()
    }

    @MainActor func tapShapeRail(_ app: XCUIApplication, beat: String) {
        let palette = app.buttons["paintpalette"].frame, photo = app.buttons["photo"].frame
        let point = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: (palette.midX + photo.midX) / 2, dy: palette.midY))
        mark(beat)
        point.tap()
    }

    @MainActor func launchCardVisible(_ app: XCUIApplication) -> Bool {
        let field = app.textFields.firstMatch
        return field.exists && field.isHittable
    }

    @MainActor func waitFor(_ timeout: Double, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline { if condition() { return true }; usleep(100_000) }
        return condition()
    }

    @MainActor func pasteBeat(_ app: XCUIApplication, _ text: String, beat: String, expectEditor: Bool = true) {
        if !waitFor(15, { launchCardVisible(app) }) { mark("MISSING launchcard before \(beat)") }
        hold(0.3)
        mark(beat)
        paste(text)
        if expectEditor && !waitFor(15, { app.buttons["xmark.circle.fill"].exists }) { mark("MISSING editor \(beat)") }
    }

    @MainActor func clearBeat(_ app: XCUIApplication, beat: String) {
        let clear = app.buttons["xmark.circle.fill"]
        guard clear.waitForExistence(timeout: 10) else { mark("MISSING \(beat)"); return }
        hold(0.3)
        mark(beat)
        clear.tap()
        for _ in 0..<3 {
            if waitFor(6, { launchCardVisible(app) }) { return }
            if clear.exists { clear.tap() }
        }
        mark("MISSING launchcard after \(beat)")
    }

    // MARK: - Storyboard 1: paste it as written

    @MainActor
    func testStoryboard1() throws {
        let ex = examples[lang]!
        let app = launchApp(lang: lang)
        _ = app.buttons["questionmark"].waitForExistence(timeout: 30)
        hold(3)
        mark("intro")
        hold(2.5)
        pasteBeat(app, ex.event, beat: "event");         hold(4.5)
        clearBeat(app, beat: "clear1");             hold(1.5)
        pasteBeat(app, ex.wifi, beat: "wifi");           hold(4.0)
        clearBeat(app, beat: "clear2");             hold(1.5)
        pasteBeat(app, ex.signature, beat: "signature"); hold(4.0)
        clearBeat(app, beat: "clear3");             hold(1.5)
        pasteBeat(app, ex.address, beat: "address");     hold(3.5)
        tapRail(app, "paintpalette", beat: "palette"); hold(1.5)
        tapTile(app, row: 1, index: 0, beat: "gradient"); hold(4.0)
        mark("end")
        snap("sb1_\(lang)_end")
    }

    // MARK: - Storyboard 2: make it yours

    @MainActor
    func testStoryboard2() throws {
        let ex = examples[lang]!
        let app = launchApp(lang: lang)
        _ = app.buttons["questionmark"].waitForExistence(timeout: 30)
        hold(3)
        mark("intro")
        hold(2.0)
        pasteBeat(app, ex.url, beat: "url", expectEditor: false);                         hold(3.0)
        tapRail(app, "paintpalette", beat: "palette");          hold(1.5)
        tapTile(app, row: 1, index: 1, beat: "gradient1");      hold(2.0)
        tapTile(app, row: 1, index: 0, beat: "gradient2");      hold(2.5)
        tapShapeRail(app, beat: "shape");                       hold(1.5)
        tapTile(app, row: 0, index: 3, beat: "modules");        hold(2.0)
        tapTile(app, row: 1, index: 2, beat: "eyes");           hold(2.5)
        tapRail(app, "photo", beat: "brand");                   hold(1.5)
        mark("logo"); dropLogo();                               hold(2.5)
        tapTile(app, row: 0, index: 1, beat: "caption");        hold(3.0)
        tapRail(app, "square.and.arrow.down", beat: "export");  hold(1.5)
        tapTile(app, row: 1, index: 4, beat: "svg");            hold(2.0)
        tapTile(app, row: 0, index: 4, beat: "size");           hold(3.5)
        mark("end")
        snap("sb2_\(lang)_end")
    }
}
