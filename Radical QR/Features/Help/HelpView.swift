import SwiftUI

/// Comprehensive help and FAQ view explaining all app capabilities and philosophy
struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                gettingStartedSection
                inputMethodsSection
                customizationSection
                exportSection
                supportedFormatsSection
                proFeaturesSection
                privacySection
            }
            .navigationTitle(String(localized: "help.fullTitle", defaultValue: "Help & Tips"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.done", defaultValue: "Done")) {
                        dismiss()
                    }
                }
            }
            #endif
        }
    }

    // MARK: - Getting Started

    private var gettingStartedSection: some View {
        Section {
            HelpRow(
                icon: "text.cursor",
                title: String(localized: "help.input.title", defaultValue: "Type or Paste"),
                detail: String(localized: "help.input.detail", defaultValue: "Enter any text, URL, email, phone number, or structured data. The app instantly generates a QR code as you type.")
            )
            HelpRow(
                icon: "sparkle.magnifyingglass",
                title: String(localized: "help.autoDetect.title", defaultValue: "Smart Auto-Detection"),
                detail: String(localized: "help.autoDetect.detail", defaultValue: "The app automatically recognizes URLs, emails, phone numbers, Wi-Fi configurations, contacts (vCard), calendar events (iCal), locations, and more. Each type is optimized for the best scanning experience.")
            )
        } header: {
            Text(String(localized: "help.section.gettingStarted", defaultValue: "Getting Started"))
        }
    }

    // MARK: - Input Methods

    private var inputMethodsSection: some View {
        Section {
            #if os(macOS)
            HelpRow(
                icon: "cursorarrow.and.square.on.square.dashed",
                title: String(localized: "help.dragDrop.title", defaultValue: "Drag & Drop"),
                detail: String(localized: "help.dragDrop.detail", defaultValue: "Drop files, text, or URLs from any app directly onto the window. Text files (.txt, .vcf, .ics) are read automatically. You can also drop web links from Safari or other browsers.")
            )
            HelpRow(
                icon: "gearshape.2",
                title: String(localized: "help.services.title", defaultValue: "macOS Services (Right-Click)"),
                detail: String(localized: "help.services.detail", defaultValue: "Right-click a phone number, email address, URL, or any selected text and choose Services › Generate QR Code. In Finder it also works on contact cards (.vcf) and calendar events (.ics).")
            )
            #endif
            HelpRow(
                icon: "square.and.arrow.up",
                title: String(localized: "help.shareExtension.title", defaultValue: "Share Sheet"),
                detail: String(localized: "help.shareExtension.detail", defaultValue: "Tap Share on a phone number, email, link, contact, or calendar event in Safari, Contacts, Calendar, Notes, and other apps, then pick Radical QR to generate a code instantly.")
            )
            HelpRow(
                icon: "link",
                title: String(localized: "help.deepLinks.title", defaultValue: "Automation & Shortcuts"),
                detail: String(localized: "help.deepLinks.detail", defaultValue: "Other apps and automations can open Radical QR with content using the radicalqr:// URL scheme. Compatible with Shortcuts and automation tools.")
            )
        } header: {
            Text(String(localized: "help.section.inputMethods", defaultValue: "Ways to Create QR Codes"))
        }
    }

    // MARK: - Customization

    private var customizationSection: some View {
        Section {
            HelpRow(
                icon: "paintpalette",
                title: String(localized: "help.colors.title", defaultValue: "Colors & Gradients"),
                detail: String(localized: "help.colors.detail", defaultValue: "Choose from preset solid colors and gradients, or unlock the full color picker with Pro. Gradient types include linear, radial, angular, and diamond.")
            )
            HelpRow(
                icon: "circle.lefthalf.filled",
                title: String(localized: "help.shape.title", defaultValue: "Shape & Roundness"),
                detail: String(localized: "help.shape.detail", defaultValue: "Adjust module roundness from sharp squares to full circles. Eye corner style and size can be set independently for unique designs.")
            )
            HelpRow(
                icon: "photo.badge.plus",
                title: String(localized: "help.logoHelp.title", defaultValue: "Logo Embedding"),
                detail: String(localized: "help.logoHelp.detail", defaultValue: "Drop or select an image to embed your logo at the center of the QR code. The quiet zone is managed automatically to maintain scannability."),
                isPro: true
            )
            HelpRow(
                icon: "textformat",
                title: String(localized: "help.caption.title", defaultValue: "Captions"),
                detail: String(localized: "help.caption.detail", defaultValue: "Add a text caption below the QR code. The app suggests a caption based on the content type, or you can write your own.")
            )
        } header: {
            Text(String(localized: "help.section.customization", defaultValue: "Customization"))
        }
    }

    // MARK: - Export

    private var exportSection: some View {
        Section {
            HelpRow(
                icon: "doc.richtext",
                title: String(localized: "help.formats.title", defaultValue: "Export Formats"),
                detail: String(localized: "help.formats.detail", defaultValue: "Export as PNG, JPEG, or WebP. Pro users also get PDF and SVG vector formats for perfect scaling at any size.")
            )
            HelpRow(
                icon: "arrow.up.left.and.arrow.down.right",
                title: String(localized: "help.sizes.title", defaultValue: "Export Sizes"),
                detail: String(localized: "help.sizes.detail", defaultValue: "Free tier exports up to 400px. Pro unlocks sizes up to 4096px for print-quality output.")
            )
            HelpRow(
                icon: "doc.on.doc",
                title: String(localized: "help.copyVsSave.title", defaultValue: "Copy vs Save"),
                detail: String(localized: "help.copyVsSave.detail", defaultValue: "Copy places the QR code on your clipboard for quick pasting. Save exports to a file you can share or archive.")
            )
        } header: {
            Text(String(localized: "help.section.export", defaultValue: "Export"))
        }
    }

    // MARK: - Supported Formats

    private var supportedFormatsSection: some View {
        Section {
            NavigationLink {
                FormatHelpContent()
            } label: {
                HelpRow(
                    icon: "qrcode",
                    title: String(localized: "help.supportedFormats.title", defaultValue: "Supported Data Formats"),
                    detail: String(localized: "help.supportedFormats.detail", defaultValue: "URLs, emails, phone numbers, Wi-Fi, contacts, calendar events, locations, and plain text -- with copyable examples.")
                )
            }
        } header: {
            Text(String(localized: "help.section.formats", defaultValue: "Data Formats"))
        }
    }

    // MARK: - Pro Features

    private var proFeaturesSection: some View {
        Section {
            HelpRow(
                icon: "clock.arrow.circlepath",
                title: String(localized: "help.history.title", defaultValue: "History & iCloud Sync"),
                detail: String(localized: "help.history.detail", defaultValue: "Your last 100 QR codes are saved and synced across devices via iCloud. Quickly reload or duplicate past creations."),
                isPro: true
            )
            HelpRow(
                icon: "star",
                title: String(localized: "help.presets.title", defaultValue: "Style Presets"),
                detail: String(localized: "help.presets.detail", defaultValue: "Save your favorite style as a reusable preset -- colors, gradient, roundness, and more."),
                isPro: true
            )
        } header: {
            Text(String(localized: "help.section.pro", defaultValue: "Pro Features"))
        }
    }

    // MARK: - Privacy

    private var privacySection: some View {
        Section {
            HelpRow(
                icon: "lock.shield",
                title: String(localized: "help.privacy.title", defaultValue: "Privacy First"),
                detail: String(localized: "help.privacy.detail", defaultValue: "Radical QR contains zero analytics, zero tracking, and zero data collection. All processing happens entirely on your device. Your content is never sent to any server. History is stored only in your private iCloud container -- nobody else can access it.")
            )
        } header: {
            Text(String(localized: "help.section.privacy", defaultValue: "Privacy"))
        }
    }
}

// MARK: - Help Row Component

struct HelpRow: View {
    let icon: String
    let title: String
    let detail: String
    var isPro: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.accent)
                .frame(width: 28, alignment: .center)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline.weight(.medium))

                    if isPro {
                        ProBadge()
                    }
                }

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Format Help Content (reusable without NavigationStack wrapper)

/// The inner content of FormatHelpView, usable as a navigation destination
struct FormatHelpContent: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(String(localized: "help.intro", defaultValue: "QR codes can encode different types of data. The app automatically detects and optimizes the format for you."))
                    .foregroundStyle(.secondary)

                ForEach(FormatExample.allExamples, id: \.type) { example in
                    FormatExampleCard(example: example)
                }
            }
            .padding()
        }
        .navigationTitle(String(localized: "help.title", defaultValue: "Supported Formats"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Preview

#Preview {
    HelpView()
        .environmentObject(PurchaseManager.shared)
}
