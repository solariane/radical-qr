import AppIntents

/// Ready-made shortcuts: they show in Spotlight, the Shortcuts app and the
/// Action button without the user building anything, and Siri recognizes their
/// phrases. The phrases' translations are in `AppShortcuts.xcstrings`, written
/// by hand: each must keep `${applicationName}`, which DeepL would not.
nonisolated struct RadicalQRShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateQRCodeIntent(),
            phrases: [
                "Create a QR code with \(.applicationName)",
                "Make a QR code with \(.applicationName)",
                "New \(.applicationName) code",
            ],
            shortTitle: LocalizedStringResource("intent.create.short", defaultValue: "Create QR Code"),
            systemImageName: "qrcode"
        )
        AppShortcut(
            intent: OpenQRCodeIntent(),
            phrases: [
                "Open a QR code in \(.applicationName)",
                "Show my QR codes in \(.applicationName)",
            ],
            shortTitle: LocalizedStringResource("intent.openCode.short", defaultValue: "My QR Codes"),
            systemImageName: "clock.arrow.circlepath"
        )
    }

    static let shortcutTileColor: ShortcutTileColor = .purple
}
