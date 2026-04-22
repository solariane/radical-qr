#!/usr/bin/env bash
#
# updLocalisation.sh - One-command localization workflow for Radical QR
#
# Steps:
#   1. Read target languages from project.pbxproj (knownRegions)
#   2. Export .xcloc files from Xcode project
#   3. Invalidate stale translations (source text changed since last run)
#   4. Translate empty targets via DeepL
#   5. Re-import translated .xcloc files back into Xcode project
#
# Requirements:
#   - DEEPL_API_KEY in ../.env (or --key=<key> or DEEPL_AUTH_KEY env var)
#   - Node.js with @xmldom/xmldom and xpath packages
#   - xcodebuild
#
# Usage:
#   ./updLocalisation.sh [--key=DEEPL_KEY] [--source=EN] [--dry-run]

set -euo pipefail

# --- Config ----------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$SCRIPT_DIR/QRCode.xcodeproj"
PBXPROJ="$PROJECT/project.pbxproj"
LOC_DIR="$SCRIPT_DIR/Localizations"
SIGS_FILE="$SCRIPT_DIR/.translation-signatures.json"
INVALIDATE_SCRIPT="$SCRIPT_DIR/invalidate-stale-translations.mjs"
TRANSLATE_SCRIPT="$SCRIPT_DIR/deepl-xcloc-translate.mjs"
ENV_FILE="$SCRIPT_DIR/../.env"

SOURCE_LANG="EN"
DRY_RUN=false

# --- Parse arguments -------------------------------------------------------

for arg in "$@"; do
    case "$arg" in
        --key=*)    export DEEPL_AUTH_KEY="${arg#--key=}" ;;
        --source=*) SOURCE_LANG="${arg#--source=}" ;;
        --dry-run)  DRY_RUN=true ;;
        --help|-h)
            echo "Usage: $0 [--key=DEEPL_AUTH_KEY] [--source=EN] [--dry-run]"
            echo ""
            echo "Options:"
            echo "  --key=KEY     DeepL API key (or set DEEPL_AUTH_KEY env var,"
            echo "                or put DEEPL_API_KEY in $ENV_FILE)"
            echo "  --source=LNG  Source language for DeepL (default: EN)"
            echo "  --dry-run     Export & invalidate only, skip translation and import"
            exit 0
            ;;
        *) echo "Unknown argument: $arg"; exit 1 ;;
    esac
done

# --- Load API key from .env if not already set -----------------------------

if [ -z "${DEEPL_AUTH_KEY:-}" ] && [ -f "$ENV_FILE" ]; then
    DEEPL_API_KEY_FROM_ENV=$(grep -E '^DEEPL_API_KEY=' "$ENV_FILE" | sed 's/^DEEPL_API_KEY=//' | tr -d '"' | tr -d "'" || true)
    if [ -n "$DEEPL_API_KEY_FROM_ENV" ]; then
        export DEEPL_AUTH_KEY="$DEEPL_API_KEY_FROM_ENV"
    fi
fi

if [ -z "${DEEPL_AUTH_KEY:-}" ] && [ "$DRY_RUN" = false ]; then
    echo "Error: No DeepL API key found."
    echo "  Set DEEPL_AUTH_KEY env var, use --key=<key>,"
    echo "  or add DEEPL_API_KEY to $ENV_FILE"
    exit 1
fi

# --- Detect free vs paid API (key ending with :fx = free) ------------------

DEEPL_API_BASE="https://api.deepl.com"
if [[ "${DEEPL_AUTH_KEY:-}" == *":fx" ]]; then
    DEEPL_API_BASE="https://api-free.deepl.com"
fi

# --- Helpers ---------------------------------------------------------------

step() { printf "\n\033[1;35m> %s\033[0m\n" "$1"; }
ok()   { printf "  \033[32m+ %s\033[0m\n" "$1"; }
warn() { printf "  \033[33m! %s\033[0m\n" "$1"; }
info() { printf "  \033[36mi %s\033[0m\n" "$1"; }

# --- Read languages from project.pbxproj ----------------------------------

step "Reading languages from project..."

if [ ! -f "$PBXPROJ" ]; then
    echo "Error: project.pbxproj not found at $PBXPROJ"
    exit 1
fi

# Extract knownRegions block, grab language codes, exclude 'en' and 'Base'
LANGUAGES=()
in_block=false
while IFS= read -r line; do
    if [[ "$line" == *"knownRegions"* ]]; then
        in_block=true
        continue
    fi
    if [ "$in_block" = true ]; then
        if [[ "$line" == *");" ]]; then
            break
        fi
        # Extract language code: strip whitespace, quotes, commas
        lang=$(echo "$line" | sed 's/[[:space:]]//g; s/"//g; s/,//g')
        if [ -n "$lang" ] && [ "$lang" != "en" ] && [ "$lang" != "Base" ]; then
            LANGUAGES+=("$lang")
        fi
    fi
done < "$PBXPROJ"

if [ ${#LANGUAGES[@]} -eq 0 ]; then
    echo "Error: No target languages found in knownRegions"
    exit 1
fi

info "Found ${#LANGUAGES[@]} target languages: ${LANGUAGES[*]}"

if [ "$DRY_RUN" = false ]; then
    if [[ "$DEEPL_API_BASE" == *"free"* ]]; then
        info "Using DeepL Free API ($DEEPL_API_BASE)"
    else
        info "Using DeepL Pro API ($DEEPL_API_BASE)"
    fi
fi

# --- Step 1: Export localizations ------------------------------------------

step "Exporting localizations from Xcode project..."

if [ -d "$LOC_DIR" ]; then
    rm -rf "$LOC_DIR"
    ok "Cleaned previous export"
fi

# Build -exportLanguage flags for each target language
EXPORT_LANG_FLAGS=()
for lang in "${LANGUAGES[@]}"; do
    EXPORT_LANG_FLAGS+=(-exportLanguage "$lang")
done

xcodebuild -exportLocalizations \
    -localizationPath "$LOC_DIR" \
    -project "$PROJECT" \
    "${EXPORT_LANG_FLAGS[@]}" \
    2>&1 | tail -20

ok "Exported to $LOC_DIR"

# Verify export produced the expected .xcloc folders
exported=0
for lang in "${LANGUAGES[@]}"; do
    if [ -d "$LOC_DIR/$lang.xcloc" ]; then
        exported=$((exported + 1))
    else
        warn "Expected $lang.xcloc not found after export"
    fi
done
info "Found $exported/${#LANGUAGES[@]} .xcloc folders"

# --- Step 2: Invalidate stale translations ---------------------------------

step "Checking for stale translations (signature-based)..."

node "$INVALIDATE_SCRIPT" "$LOC_DIR" --sigs="$SIGS_FILE"

# --- Step 3: Translate with DeepL ------------------------------------------

if [ "$DRY_RUN" = true ]; then
    warn "Dry run -- skipping DeepL translation and import"
    echo ""
    echo "Stale translations have been cleared. Run without --dry-run to translate."
    exit 0
fi

step "Translating empty entries via DeepL (source=$SOURCE_LANG)..."

DEEPL_AUTH_KEY="$DEEPL_AUTH_KEY" node "$TRANSLATE_SCRIPT" \
    "$LOC_DIR" \
    --inplace \
    --source="$SOURCE_LANG" \
    --api-base="$DEEPL_API_BASE"

ok "Translation complete"

# --- Step 4: Import back into Xcode project --------------------------------

step "Importing translations back into Xcode project..."

imported=0
for lang in "${LANGUAGES[@]}"; do
    xcloc="$LOC_DIR/$lang.xcloc"
    if [ -d "$xcloc" ]; then
        echo "  Importing $lang..."
        xcodebuild -importLocalizations \
            -localizationPath "$xcloc" \
            -project "$PROJECT" \
            2>&1 | tail -3
        imported=$((imported + 1))
    else
        warn "No .xcloc found for $lang -- skipping"
    fi
done

ok "Imported $imported language(s)"

# --- Done ------------------------------------------------------------------

step "Localization update complete!"
echo ""
echo "  Signatures: $SIGS_FILE"
echo "  Languages:  ${LANGUAGES[*]}"
echo ""
echo "  Review changes in Xcode before committing."
