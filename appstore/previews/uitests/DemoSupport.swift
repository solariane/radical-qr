import XCTest

// Shared helpers for the App Preview capture tests. Copied into the scratch
// project's "Radical QRUITests" folder by appstore/previews/shoot.sh, never
// built from the repository itself.

/// Where the test writes marks and screenshots, and reads the paste and logo
/// hand-offs. shoot.sh passes it as TEST_RUNNER_DEMO_WORK_DIR.
let workDir = ProcessInfo.processInfo.environment["DEMO_WORK_DIR"] ?? "/tmp/radicalqr-previews"
let outDir = workDir + "/uitest"
let pasteFile = outDir + "/paste.txt"
let logoDrop = outDir + "/logo.png"
let logoSource = workDir + "/logo.png"

@MainActor func dump(_ name: String, _ text: String) {
    try? text.write(toFile: "\(outDir)/\(name).txt", atomically: true, encoding: .utf8)
}
@MainActor func snap(_ name: String) {
    try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
}
/// Appends a wall-clock mark so the recording can be cut on it later.
@MainActor func mark(_ label: String) {
    let line = String(format: "%.3f %@\n", Date().timeIntervalSince1970, label)
    let url = URL(fileURLWithPath: "\(outDir)/marks.txt")
    if let h = try? FileHandle(forWritingTo: url) { h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); h.closeFile() }
    else { try? line.write(to: url, atomically: true, encoding: .utf8) }
}
/// Hands text to the app's DEBUG paste hook and waits until it was taken.
@MainActor func paste(_ text: String) {
    try? text.write(toFile: pasteFile, atomically: true, encoding: .utf8)
    let deadline = Date().addingTimeInterval(20)
    while FileManager.default.fileExists(atPath: pasteFile) && Date() < deadline { usleep(20_000) }
    mark("paste")
}
@MainActor func launchApp(lang: String) -> XCUIApplication {
    let app = XCUIApplication()
    let locale = ["en": "en_US", "fr": "fr_FR", "de": "de_DE", "es": "es_ES"][lang] ?? lang
    app.launchArguments = ["-AppleLanguages", "(\(lang))", "-AppleLocale", locale,
                           "-debug_pro_override", "forcePro"]
    try? FileManager.default.removeItem(atPath: pasteFile)
    try? FileManager.default.removeItem(atPath: logoDrop)
    app.launchEnvironment["DEMO_PASTE_FILE"] = pasteFile
    app.launchEnvironment["DEMO_LOGO_FILE"] = logoDrop
    app.launchEnvironment["DEMO_EMPTY_HISTORY"] = "1"
    // Mac only: where the window goes, so the screen recording frames it.
    if let frame = ProcessInfo.processInfo.environment["DEMO_WINDOW"] {
        app.launchEnvironment["DEMO_WINDOW"] = frame
    }
    app.launch()
    return app
}

/// Hands the logo to the app's DEBUG hook (stands in for the Photos pick).
@MainActor func dropLogo() {
    try? FileManager.default.copyItem(atPath: logoSource, toPath: logoDrop)
    let deadline = Date().addingTimeInterval(20)
    while FileManager.default.fileExists(atPath: logoDrop) && Date() < deadline { usleep(20_000) }
    mark("logo")
}

struct DemoExamples {
    let event: String, wifi: String, signature: String, address: String, url: String
}

let examples: [String: DemoExamples] = [
    "en": DemoExamples(
        event: "Dinner Saturday 8pm, 350 Fifth Avenue, New York",
        wifi: "Wi-Fi: CafeGuest\nPassword: espresso2026",
        signature: "Emma Collins, Head of Design\nNorthwind Studio\n+1 415 555 0142\nemma@northwindstudio.com\nnorthwindstudio.com",
        address: "350 Fifth Avenue, New York, NY 10118",
        url: "https://radicalsolution.com"),
    "fr": DemoExamples(
        event: "Dîner samedi 20h, 12 rue de Rivoli, Paris",
        wifi: "Wi-Fi : Livebox-A1B2\nMot de passe : croissant2026",
        signature: "Camille Martin, Directrice artistique\nAtelier Nord\n+33 6 12 34 56 78\ncamille@ateliernord.fr\nateliernord.fr",
        address: "12 rue de Rivoli, 75004 Paris",
        url: "https://radicalsolution.com"),
    "de": DemoExamples(
        event: "Abendessen Samstag 20 Uhr, Hauptstraße 5, Berlin",
        wifi: "WLAN: CafeGast\nPasswort: brezel2026",
        signature: "Lena Schneider, Leiterin Design\nNordlicht GmbH\n+49 30 12345678\nlena@nordlicht.de\nnordlicht.de",
        address: "Hauptstraße 5, 10827 Berlin",
        url: "https://radicalsolution.com"),
    "es": DemoExamples(
        event: "Cena sábado 20h, Calle Gran Vía 28, Madrid",
        wifi: "Wi-Fi: CafeInvitado\nContraseña: churros2026",
        signature: "Lucía García, Directora de diseño\nEstudio Norte\n+34 612 345 678\nlucia@estudionorte.es\nestudionorte.es",
        address: "Calle Gran Vía 28, 28013 Madrid",
        url: "https://radicalsolution.com"),
]

@MainActor func clearInput(_ app: XCUIApplication) {
    let clear = app.buttons["xmark.circle.fill"]
    if clear.waitForExistence(timeout: 5) { clear.tap() }
    mark("clear")
}
