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
