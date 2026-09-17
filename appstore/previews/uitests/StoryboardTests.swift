import XCTest
#if os(macOS)
import CoreGraphics
#endif

/// Drives the two App Preview storyboards. Every visible action is preceded by
/// a mark "<beat>"; the edit keeps the first recorded frame after each mark
/// plus a hold, so the time XCTest spends between actions never reaches the cut.
final class StoryboardTests: XCTestCase {
    var lang: String { ProcessInfo.processInfo.environment["DEMO_LANG"] ?? "en" }

    @MainActor func hold(_ s: Double) { usleep(useconds_t(s * 1_000_000)) }

    /// Mac only: XCTest leaves the pointer where it clicked, and teleports it to the
    /// next click. Park it left of the window, outside the recorded rectangle.
    @MainActor func parkPointer(_ app: XCUIApplication) {
        #if os(macOS)
        // hover() stays inside the app's window; warping is not limited to it.
        let window = app.windows.firstMatch.frame
        CGWarpMouseCursorPosition(CGPoint(x: max(window.minX - 60, 5), y: window.midY))
        #endif
    }

    /// Tiles of the family panel under the rail, grouped into rows top to bottom.
    @MainActor func panelRows(_ app: XCUIApplication) -> [[XCUIElement]] {
        let rail = app.buttons["paintpalette"].frame
        // On a Mac (split layout) the panel sits in the right-hand column only.
        let left = app.buttons["star"].frame.minX - 12
        let tiles = app.buttons.allElementsBoundByIndex.filter {
            let f = $0.frame
            return f.minY > rail.maxY + 4 && f.minX >= left && f.width <= 150 && f.height >= 40 && f.height <= 80  // a selected Mac tile is 71pt
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
        #if os(macOS)
        let bottom = app.windows.firstMatch.frame.maxY - 40
        #else
        let bottom: CGFloat = 840
        #endif
        if rows.count <= row || rows[row].count <= index || rows[row][index].frame.maxY > bottom {
            app.scrollViews.firstMatch.swipeUp(velocity: .slow)
            hold(1.0)
            rows = panelRows(app)
        }
        guard rows.count > row, rows[row].count > index else { mark("MISSING \(beat)"); return }
        let tile = rows[row][index]
        mark(beat)
        tile.tap()
        parkPointer(app)
        // A tap can be swallowed while the machine is busy: the tile says whether it took.
        if !waitFor(4, { tile.isSelected }) {
            mark("retap \(beat)")
            tile.tap()
            parkPointer(app)
            if !waitFor(4, { tile.isSelected }) { mark("MISSING selection \(beat)") }
        }
    }

    @MainActor func tapRail(_ app: XCUIApplication, _ id: String, beat: String) {
        let b = app.buttons[id]
        _ = b.waitForExistence(timeout: 10)
        mark(beat)
        b.tap()
        parkPointer(app)
    }

    @MainActor func tapShapeRail(_ app: XCUIApplication, beat: String) {
        let palette = app.buttons["paintpalette"].frame, photo = app.buttons["photo"].frame
        // From the window, not the app: on a Mac the application element has no frame.
        let window = app.windows.firstMatch
        let origin = window.frame.origin
        let point = window.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: (palette.midX + photo.midX) / 2 - origin.x, dy: palette.midY - origin.y))
        mark(beat)
        point.tap()
        parkPointer(app)
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
        parkPointer(app)
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
        parkPointer(app)
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
        parkPointer(app)
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
        #if os(macOS)
        // The Mac's split layout clips the last two of five tiles (4096, SVG), so
        // pick ones that show in full there: PDF and 2048.
        tapTile(app, row: 1, index: 2, beat: "svg");            hold(2.0)
        tapTile(app, row: 0, index: 3, beat: "size");           hold(3.5)
        #else
        tapTile(app, row: 1, index: 4, beat: "svg");            hold(2.0)
        tapTile(app, row: 0, index: 4, beat: "size");           hold(3.5)
        #endif
        mark("end")
        snap("sb2_\(lang)_end")
    }
}
