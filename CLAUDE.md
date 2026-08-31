# Radical QR - iOS/macOS App

## Project Overview

**App Name**: Radical QR
**Bundle ID**: `radicalsolution.com.Radical-QR`

A native iOS/macOS QR code generator app with a freemium business model. The app prioritizes **privacy** (no tracking, no logging), **elegance**, and **efficiency**. Users can generate QR codes via drag & drop or text input with live preview and extensive customization options.

### Design Philosophy

- **Visual Identity**: Vibrant purple-to-violet gradient background (`linear-gradient(135deg, #667eea 0%, #764ba2 100%)`) with clean white content areas, soft rounded corners (24px), and smooth animations
- **UX Principle**: "Radically simple" - users should never have to decide format or action beforehand; the interface adapts to their needs
- **Privacy First**: Zero tracking, zero logging, ephemeral processing only

---

## Technical Stack

### Platform & Frameworks

- **Target**: iOS 17+ / macOS 14+ (Sonoma)
- **Language**: Swift 6 with strict concurrency
- **UI Framework**: SwiftUI (exclusively)
- **Architecture**: MVVM with clear separation of concerns
- **QR Generation**: Core Image (`CIQRCodeGenerator`) with custom rendering pipeline
- **Storage**: SwiftData for history (Pro feature)
- **Cloud Sync**: CloudKit for iCloud sync (Pro feature)
- **In-App Purchase**: StoreKit 2

### Project Structure

```
Radical QR/
├── RadicalQRApp.swift                   # App entry point (@main)
├── ContentView.swift                    # Root navigation view
├── Info.plist                           # App config + NSServices declaration
├── Assets.xcassets/                     # App icons, colors
├── Core/
│   ├── Models/
│   │   ├── QRCodeConfiguration.swift    # QR code settings model
│   │   ├── DataType.swift               # Data type detection enum
│   │   ├── ExportFormat.swift           # Export format enum
│   │   ├── URLMetadata.swift            # URL/social profile metadata
│   │   └── HistoryItem.swift            # SwiftData model for history
│   └── Services/
│       ├── QRCodeGenerator.swift        # Core QR generation (Core Image)
│       ├── QRCodeRenderer.swift         # Custom rendering with styles
│       ├── DataTypeDetector.swift       # Auto-detect input type + summarize
│       ├── ExportService.swift          # Export to various formats (incl. SVG)
│       ├── PurchaseManager.swift        # StoreKit 2 wrapper
│       ├── CaptionGenerator.swift       # Auto-caption from QR content
│       ├── AppDelegate.swift            # macOS: Services registration + URL interception
│       ├── ServicesProvider.swift        # macOS: right-click Services handler
│       └── DeepLinkHandler.swift        # radicalqr:// URL scheme handler
├── Features/
│   ├── Generator/
│   │   ├── GeneratorView.swift          # Main generation interface
│   │   ├── GeneratorViewModel.swift     # Reactive view model
│   │   ├── CustomizationRail.swift      # Icon rail: 5 setting families, one shown at a time
│   │   ├── ColorGroupView.swift         # Solid, gradient, background
│   │   ├── ShapeGroupView.swift         # Modules, eyes, eye size
│   │   ├── BrandGroupView.swift         # Logo + caption
│   │   ├── SavedStylesStrip.swift       # Pro: the user's own saved styles
│   │   └── CustomizationPanel.swift     # Legacy sheet — still used by Settings
│   ├── Export/
│   │   └── ExportView.swift             # Export options sheet
│   ├── History/
│   │   ├── HistoryView.swift            # Pro: history list
│   │   └── RecentHistoryStrip.swift     # Recent items horizontal strip
│   ├── Settings/
│   │   └── SettingsView.swift           # Preferences & style presets
│   └── Paywall/
│       └── PaywallView.swift            # Pro upgrade screen
├── Shared/
│   ├── Components/
│   │   ├── GradientBackground.swift     # App background
│   │   ├── DropZone.swift               # Drag & drop target
│   │   ├── InputZone.swift              # Text input area
│   │   ├── ColorPickerView.swift        # Color selection
│   │   ├── SettingTile.swift            # The one control shape: squircle + concentric ring
│   │   ├── ShapeGlyphs.swift            # Vector previews — every option draws its result
│   │   ├── RoundnessSlider.swift        # QR element roundness
│   │   └── LogoDropZone.swift           # Logo embedding (Pro)
│   └── Modifiers/
│       └── CardStyle.swift              # Consistent card styling
└── Resources/
    ├── Localizable.xcstrings            # 7 languages
    └── InfoPlist.xcstrings              # Plist display name translations

RadicalQRShare/                          # Share Extension (iOS + macOS)
├── Info.plist                           # Activation rule (text, URL, vCard, iCal)
├── ShareViewController.swift            # Platform-split: NSViewController / UIViewController
└── ShareExtensionView.swift             # SwiftUI share UI (preview + copy + open in app)
```

---

## Feature Specification

### Free Tier

| Feature | Specification |
|---------|---------------|
| **Colors** | 6 solid colors: Black, Navy (#1e3a5f), Forest (#2d5a3d), Burgundy (#722f37), Charcoal (#36454f), Indigo (#4b0082) |
| **Gradients** | 3 color gradients: Purple-Violet, Blue-Cyan, Orange-Pink |
| **Gradient Types** | 2 types: Linear (diagonal), Radial |
| **Background** | White or Transparent |
| **Export Formats** | PNG, JPEG, WebP |
| **Export Size** | Maximum 400px |
| **Logo Embedding** | No |
| **History** | No |
| **Roundness** | Yes (full access) |

### Pro Tier (In-App Purchase)

| Feature | Specification |
|---------|---------------|
| **Colors** | Full system color picker |
| **Gradients** | Full color picker for gradient stops |
| **Gradient Types** | Linear (all angles), Radial, Angular, Diamond |
| **Background** | White or Transparent |
| **Export Formats** | PNG, JPEG, WebP, **PDF**, **SVG** |
| **Export Size** | Unlimited (up to 4096px) |
| **Logo Embedding** | Yes (centered, with automatic quiet zone) |
| **History** | Yes (last 100 items, iCloud sync) |
| **Roundness** | Yes |
| **Style Preset** | Save up to 4 custom styles (`FeatureLimit.maxStylePresets`), recalled from the generator's "My styles" family |
| **Duplication** | Duplicate from history |
| **Future: Templates** | Ready for preset templates (Instagram, Restaurant Menu, etc.) |

---

## Data Type Detection

The app automatically detects and optimizes QR encoding for:

| Type | Detection Pattern | Optimization |
|------|-------------------|--------------|
| URL | `https?://`, `www.` prefix | URL encoding |
| Email | `mailto:` or valid email pattern | mailto: prefix |
| Phone | `tel:` or phone number pattern | tel: prefix |
| SMS | `sms:` or `smsto:` | SMS encoding |
| WiFi | `WIFI:` prefix | WiFi config format |
| vCard | `BEGIN:VCARD` | Contact encoding |
| iCalendar | `BEGIN:VCALENDAR` / `BEGIN:VEVENT` | Calendar event encoding |
| Geographic | `geo:` or coordinates | Geo URI |
| Plain Text | Fallback | Alphanumeric/byte encoding |

---

## Localization

### Supported Languages

| Code | Language |
|------|----------|
| `en` | English (base) |
| `fr` | French |
| `de` | German |
| `es` | Spanish |
| `it` | Italian |
| `pt-BR` | Portuguese (Brazil) |
| `ja` | Japanese |
| `ar` | Arabic |
| `hi` | Hindi |
| `zh-Hans` | Chinese (Simplified) |

### Localization Guidelines

- Use `String(localized:)` for all user-facing strings
- Keys follow pattern: `feature.component.element` (e.g., `generator.input.placeholder`)
- Include pluralization rules where applicable
- Arabic requires right-to-left (RTL) layout support
- Japanese requires careful character width consideration in UI

---

## Code Standards

### Swift Style

```swift
// MARK: - Preferred patterns

// 1. Explicit types for public API, inference for local
public func generate(from input: String) -> QRCode { }
let configuration = QRCodeConfiguration()

// 2. Async/await with structured concurrency
func exportImage() async throws -> Data {
    try await withCheckedThrowingContinuation { continuation in
        // ...
    }
}

// 3. Protocol-oriented design
protocol QRCodeRenderable {
    func render(with configuration: QRCodeConfiguration) -> Image
}

// 4. Value types preferred
struct QRCodeConfiguration: Codable, Hashable, Sendable {
    var foregroundColor: ColorScheme
    var backgroundColor: BackgroundType
    var roundness: CGFloat // 0.0 to 1.0
    var logo: LogoConfiguration?
}

// 5. Minimal optionals - use sensible defaults
struct ColorScheme: Codable, Hashable, Sendable {
    var type: ColorType = .solid
    var primaryColor: Color = .black
    var secondaryColor: Color? // Only for gradients
    var gradientType: GradientType = .linear
}
```

### SwiftUI Conventions

```swift
// MARK: - View structure

struct GeneratorView: View {
    // 1. Environment first
    @Environment(\.colorScheme) private var colorScheme

    // 2. State objects
    @StateObject private var viewModel = GeneratorViewModel()

    // 3. State properties
    @State private var isExporting = false

    // 4. Body
    var body: some View {
        content
            .background(GradientBackground())
    }

    // 5. Extracted subviews as computed properties
    private var content: some View {
        // ...
    }
}

// MARK: - ViewModel pattern

@MainActor
final class GeneratorViewModel: ObservableObject {
    @Published private(set) var qrCode: Image?
    @Published var configuration = QRCodeConfiguration()

    private let generator: QRCodeGenerator

    // Dependency injection
    init(generator: QRCodeGenerator = .init()) {
        self.generator = generator
    }
}
```

### Architecture Rules

1. **Views** are purely declarative - no business logic
2. **ViewModels** are `@MainActor` and `ObservableObject`
3. **Services** are stateless and injectable
4. **Models** are value types (`struct`) and `Sendable`
5. **No force unwrapping** except for known-safe scenarios (IB outlets, etc.)
6. **No `print()` debugging** - use OSLog for any logging
7. **Errors are typed** - create specific error enums

### Performance Guidelines

- QR generation happens on background thread
- Live preview uses debouncing (200ms delay after input changes)
- Images are cached during session
- Export operations show non-blocking progress
- History uses lazy loading with pagination

---

## Testing Requirements

### Unit Tests

- QR generation correctness for all data types
- Color/gradient rendering accuracy
- Data type detection coverage
- Export format validation
- Purchase state management

### UI Tests

- Drag & drop functionality
- Input field interaction
- Customization controls
- Export flow
- Paywall presentation

### Test Coverage Target

- Core Services: 90%+
- ViewModels: 80%+
- Overall: 70%+

---

## Privacy Compliance

### Data Handling

- **No analytics SDK** - zero tracking
- **No crash reporting** with user data
- **Input data** is never stored (except explicit history in Pro)
- **History** is local + iCloud only, never server-side
- **Export** happens entirely on-device

### Privacy Policy Points

- App does not collect personal data
- QR content is processed locally and immediately discarded
- Pro history is stored in user's private iCloud container
- No third-party services receive any data

---

## Build Configuration

### Schemes

- `Debug` - Development builds
- `Release` - Production builds
- `TestFlight` - Beta distribution

### Feature Flags

```swift
enum FeatureFlag {
    static let enableTemplates = false  // Future feature
    static let maxHistoryItems = 100
    static let freeMaxExportSize = 400
    static let proMaxExportSize = 4096
}
```

---

## App Store Metadata

> **Automation**: localized metadata lives in `appstore/metadata/<locale>/*.txt`
> (en-US is the hand-written source of truth) and is translated + pushed to
> App Store Connect via `./updAppStore.sh`. Full pipeline docs, per-field rules,
> and required credentials are in [`appstore/README.md`](appstore/README.md).
> Brand names are auto-protected during translation (see `deepl-protect.mjs`).

### Category

- Primary: Utilities
- Secondary: Productivity

### Keywords (per language)

Focus on: QR code, generator, creator, privacy, no tracking, custom, logo, export

### Screenshots Required

1. Main generator interface with gradient background
2. Customization panel showing colors/gradients
3. QR code with embedded logo (Pro)
4. Export options
5. History view (Pro)

---

## Future Roadmap (Post-v1)

1. **Templates/Presets**: Pre-configured styles for common use cases
2. **Batch Generation**: Multiple QR codes from CSV/list
3. **Apple Watch**: Quick generation from recent history
4. **Widgets**: Home screen widgets for favorite QR codes
5. **Shortcuts Integration**: Siri and Shortcuts app support

---

## macOS Integration

### Services (right-click menu)

Declared in `Info.plist` under `NSServices`. The `ServicesProvider` class handles
the `generateQR` selector. Supported pasteboard types:
- `public.url`, `public.plain-text`, `public.utf8-plain-text`
- `public.vcard`, `com.apple.ical.ics`

When a `file://` URL is received (e.g. right-clicking a .vcf/.ics file in Finder),
`DataTypeDetector.extractContent(from:)` reads the file content instead of using
the file path.

**Cold-launch handling**: `ServicesProvider.pendingContent` stores content for
views that haven't mounted yet. `activateApp()` retries with delays + forces
`NSApp.setActivationPolicy(.regular)` + `window.orderFrontRegardless()`.

### Share Extension (Share menu)

`RadicalQRShare` target — multi-platform (iOS + macOS). Activation rule supports:
`public.plain-text`, `public.url`, `public.vcard`, `public.calendar-event`.

| Platform | View Controller | Content passing to main app |
|----------|----------------|---------------------------|
| macOS | `NSViewController` + `NSHostingController` | Dedicated `NSPasteboard` + `radicalqr://paste` URL |
| iOS | `UIViewController` + `UIHostingController` | `radicalqr://create?content=…` via `URLComponents` |

On macOS, the `AppDelegate.application(_:open:)` intercepts URLs to prevent
SwiftUI from creating a second window, reads content from the pasteboard, and
delivers via `ServicesProvider.contentReceived` notification.

### Deep Link URL scheme

`radicalqr://create?content=<encoded>` — standard deep link (iOS + macOS)
`radicalqr://paste` — macOS only, reads from pasteboard `com.radicalsolution.radicalqr.share`

### SVG Export

`ExportService.exportSVG()` generates optimized SVG with run-length encoded paths.
**Important**: `colorToHex()` must clamp color components to 0…1 before hex
conversion — extended color spaces (Display P3) can produce out-of-range values.

---

## Commands Reference

```bash
# Build
xcodebuild -scheme "Radical QR" -configuration Debug build

# Test
xcodebuild -scheme "Radical QR" -configuration Debug test

# Localization — ONE-COMMAND workflow (preferred)
#   Wrapper ./updLocalisation.sh does the full pipeline:
#     1. Read target languages from QRCode.xcodeproj/project.pbxproj (knownRegions)
#     2. xcodebuild -exportLocalizations  → ./Localizations/<lang>.xcloc
#     3. invalidate-stale-translations.mjs → clears targets whose source text changed
#        (so edited strings get re-translated, not just brand-new keys)
#     4. deepl-xcloc-translate.mjs → fills empty <target> entries via DeepL
#     5. xcodebuild -importLocalizations → writes back into the .xcstrings catalogs
#   Requires: Node.js + @xmldom/xmldom & xpath, xcodebuild, and a DeepL key.
#   Key resolution order: --key=<key>  >  $DEEPL_AUTH_KEY  >  DEEPL_API_KEY in ../.env
#   (i.e. /Volumes/fastMe/Code/.env holds DEEPL_API_KEY; the wrapper maps it to
#    DEEPL_AUTH_KEY for the node scripts. A key ending in ":fx" auto-selects the free API.)
./updLocalisation.sh --source=EN
./updLocalisation.sh --dry-run        # export + invalidate only, no DeepL calls / no import

# Brand protection: brand/product names are kept identical across ALL locales
# automatically. deepl-protect.mjs wraps each protected term in <x>..</x> and the
# DeepL call uses tag_handling=xml + ignore_tags=x, so "Radical QR",
# "Phone Numbers Cleaner", "RadicalSolution.com" are never transliterated.
# To protect a new term: add it to DEFAULT_PROTECTED_TERMS in deepl-protect.mjs
# (xcloc strings) AND to "protectedTerms" in appstore/config.json (App Store).

# Manual equivalents (only if not using the wrapper):
xcodebuild -exportLocalizations -localizationPath ./Localizations -project QRCode.xcodeproj
DEEPL_AUTH_KEY=<key> node deepl-xcloc-translate.mjs ./Localizations --inplace --source=EN
xcodebuild -importLocalizations -localizationPath ./Localizations/<lang>.xcloc -project QRCode.xcodeproj

# App Store Connect metadata — translate + push (full docs: appstore/README.md)
#   Source of truth: appstore/metadata/en-US/*.txt ; config: appstore/config.json
#   Hash-based invalidation, brand protection, ASC push via App Store Connect API.
#   Credentials in ../.env: DEEPL_API_KEY, ASC_ISSUER_ID, ASC_KEY_ID, ASC_KEY_PATH
./updAppStore.sh                  # translate stale/missing locales + push
./updAppStore.sh --translate-only # DeepL only, no ASC push
./updAppStore.sh --push-only      # push existing metadata, no retranslate
./updAppStore.sh --dry-run        # show changes without touching ASC
# In-App Purchase setup (StoreKit products on ASC): ./createIAP.sh  (see appstore-iap-create.mjs)

# Generate app icon (requires source 1024x1024)
# Use Asset Catalog for automatic generation
```

---

## Generator UI conventions

The generator's settings never name an option in text: each one draws its own
result (`ShapeGlyphs.swift`) inside the single `SettingTile` shape. Words in a
68pt-wide capsule are what turned "Rounded" into "Arron-di" on a French phone,
so a new option means a new glyph, not a new label — the localized string stays
for VoiceOver only. Glyph geometry mirrors `QRCodeRenderer` (7-unit eye, 1-unit
ring, 3-unit pupil, even-odd fill) so a tile shows what the exporter draws.

One family is on screen at a time, which is what keeps preview, settings and the
save button on an iPhone SE without scrolling. Adding a permanent row above the
groups costs every family its height — that is why saved styles became a family
rather than a band. Check the vertical budget before adding anything there.

## Notes for Claude

- Always prefer composition over inheritance
- Keep files under 300 lines; extract when larger
- Use `#Preview` macros for all views
- Commit atomic changes with clear messages
- When adding features, update this document
- Test on both iOS and macOS targets
- Ensure accessibility labels for all interactive elements
