# App Store metadata pipeline

This folder holds the source of truth for all **App Store Connect** metadata
(localized per language). It follows the [fastlane `deliver` file layout](https://docs.fastlane.tools/actions/deliver/#uploading-metadata)
so the files stay tool-agnostic.

```
appstore/
├── config.json                        # locales, DeepL mapping, field limits
├── metadata/
│   ├── en-US/                         # SOURCE OF TRUTH (hand-written)
│   │   ├── name.txt                   (≤ 30 chars)
│   │   ├── subtitle.txt               (≤ 30 chars)
│   │   ├── description.txt            (≤ 4000 chars)
│   │   ├── keywords.txt               (≤ 100 chars, comma-separated)
│   │   ├── promotional_text.txt       (≤ 170 chars)
│   │   ├── support_url.txt
│   │   ├── marketing_url.txt
│   │   └── privacy_url.txt
│   ├── fr-FR/                         # Hand-written (flagged in config.json)
│   ├── de-DE/                         # Auto-translated
│   ├── es-ES/                         #
│   ├── it/                            #
│   ├── pt-BR/                         #
│   ├── ja/                            #
│   ├── ar-SA/                         #
│   ├── hi/                            #
│   └── zh-Hans/                       #
└── .appstore-signatures.json          # per-field SHA256 of source, auto-managed
```

## Workflow

From the project root:

```bash
# Full pipeline: translate missing/stale locales + push to App Store Connect
./updAppStore.sh

# Translate only (no push)
./updAppStore.sh --translate-only

# Push only (no retranslate)
./updAppStore.sh --push-only

# Dry run — shows what would change without touching ASC
./updAppStore.sh --dry-run

# Force re-translation of everything (ignore hash cache)
./updAppStore.sh --force

# Restrict to some locales
./updAppStore.sh --only=fr-FR,de-DE
```

## How invalidation works

The script stores a `sha256(source_text)` per locale/field in
`.appstore-signatures.json`. On the next run:

- If the source hash matches the stored one → the target is considered up-to-date (skip)
- If the source changed → the target is re-translated
- If a hand-written locale (like `fr-FR`) is missing a field → it's flagged, never auto-translated

## Required credentials (`.env` at repo root)

```env
# DeepL — free keys end with :fx
DEEPL_API_KEY=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx:fx

# App Store Connect — from App Store Connect → Users & Access → Keys
ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
ASC_KEY_ID=ABCDE12345
ASC_KEY_PATH=~/.appstoreconnect/AuthKey_ABCDE12345.p8
```

Generate the ASC API key from App Store Connect → Users & Access → Keys →
"App Manager" or higher role. Download the `.p8` once (it cannot be re-downloaded)
and store it outside the repo. The `ASC_KEY_PATH` can use `~/` expansion.

## Per-field rules

| Field               | Translated? | Locale-aware URL? | Notes                                                    |
| ------------------- | ----------- | ----------------- | -------------------------------------------------------- |
| `name.txt`          | yes         | —                 | App display name — app-level field (shared across version). |
| `subtitle.txt`      | yes         | —                 | App-level, per-locale. Strict 30-char limit.             |
| `description.txt`   | yes         | —                 | Per-version, per-locale. 4000 chars.                     |
| `keywords.txt`      | yes         | —                 | Comma-separated. 100 chars total. Review manually — search terms differ by culture. |
| `promotional_text.txt` | yes      | —                 | 170 chars. Editable without submitting a new version.    |
| `release_notes.txt` | yes         | —                 | "What's New" (`whatsNew`). Per-version, 4000 chars. Must be empty/absent for the very first version. |
| `support_url.txt`   | no          | yes               | `/en/` segment is replaced per target locale.            |
| `marketing_url.txt` | no          | yes               | Same as above.                                           |
| `privacy_url.txt`   | no          | yes               | Same as above. App-level field.                          |

## What the push script touches

The push script only touches the **current editable version** in App Store Connect
(state `PREPARE_FOR_SUBMISSION`, `DEVELOPER_REJECTED`, `REJECTED`,
`METADATA_REJECTED`, or `WAITING_FOR_REVIEW`). If no such version exists, it
exits cleanly — no action is taken.

- `description`, `keywords`, `promotionalText`, `whatsNew`, `supportUrl`, `marketingUrl`
  are pushed to the version localization.
- `name`, `subtitle`, `privacyPolicyUrl` are pushed to the **appInfo**
  localization (app-level, shared across versions).

Fields not present locally are never cleared on ASC — missing files mean
"don't touch", not "erase".

---

## Screenshots

Screenshots are a separate pipeline — `appstore-push.mjs` only handles text — and
they are **drawn, not captured**: each scene is a Node script that writes an SVG
in which the app's screen is redrawn, then rasterised with `rsvg-convert`. No
simulator and no app build are involved.

```bash
# Everything: translate the copy, render every locale, upload
./updScreenshots.sh

./updScreenshots.sh --render-only      # no DeepL, no App Store Connect
./updScreenshots.sh --upload-only      # send what is already in out/
./updScreenshots.sh --dry-run
./updScreenshots.sh --only=fr-FR,de-DE
./updScreenshots.sh --clean            # wipe out/ before rendering
```

Requires `rsvg-convert`:

```bash
brew install librsvg
```

**Text** lives in `appstore/screenshots/copy/<locale>.json`, with `en-US` as the
source of truth and `fr-FR` hand-written (`isHandWritten` in `config.json`, same
as the metadata). The other locales come from `translate-copy.mjs`, which reuses
this pipeline's brand protection and hash-based invalidation, and sends the app
description plus a per-key note as DeepL `context`. Strings that also exist in
the app are copied verbatim from `Localizable.xcstrings` — a screenshot whose
button says something different from the app reads as a different app.

**Drawing** lives in `appstore/screenshots/lib/app-ui.mjs`, which mirrors the
real SwiftUI components at the real `GeneratorMetrics` values. Screens are laid
out in app points and scaled into the device frame, so a layout change in the app
is mirrored by copying numbers rather than re-tuning a drawing. When
`GeneratorMetrics` changes, update `METRICS` there and re-render.

Full notes, scene list and open items: `appstore/screenshots/MEMO-2.0.md`.
