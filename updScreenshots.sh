#!/usr/bin/env bash
#
# updScreenshots.sh — One-command App Store screenshot workflow for Radical QR.
#
# The counterpart to updAppStore.sh, which handles the text. Screenshots were
# left out of appstore-push.mjs entirely, so they had to be dropped into App
# Store Connect by hand; this closes that gap.
#
# Steps:
#   1. Translate copy/en-US.json into the target locales via DeepL
#      (hash-based invalidation; fr-FR is hand-written and never touched)
#   2. Render every scene to SVG, then to the PNG sizes Apple accepts
#   3. Upload to App Store Connect's editable version, per locale and device
#
# Requirements:
#   - rsvg-convert (brew install librsvg)
#   - Node.js
#   - DEEPL_API_KEY in ../.env               (step 1)
#   - ASC_ISSUER_ID, ASC_KEY_ID, ASC_KEY_PATH in ../.env  (step 3)
#
# Usage:
#   ./updScreenshots.sh                      # translate + render + upload
#   ./updScreenshots.sh --render-only        # no DeepL, no upload
#   ./updScreenshots.sh --upload-only        # upload what is already in out/
#   ./updScreenshots.sh --no-translate       # render + upload, skip DeepL
#   ./updScreenshots.sh --dry-run            # show what would happen
#   ./updScreenshots.sh --only=fr-FR,de-DE   # restrict to some locales
#   ./updScreenshots.sh --force              # re-translate even if unchanged
#   ./updScreenshots.sh --clean              # wipe out/ before rendering

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"
SHOTS_DIR="$SCRIPT_DIR/appstore/screenshots"

TRANSLATE=true
RENDER=true
UPLOAD=true
DRY_RUN=false
FORCE=false
CLEAN=false
ONLY=""

for arg in "$@"; do
    case "$arg" in
        --render-only)  TRANSLATE=false; UPLOAD=false ;;
        --upload-only)  TRANSLATE=false; RENDER=false ;;
        --no-translate) TRANSLATE=false ;;
        --dry-run)      DRY_RUN=true ;;
        --force)        FORCE=true ;;
        --clean)        CLEAN=true ;;
        --only=*)       ONLY="${arg#--only=}" ;;
        --help|-h)
            sed -n '3,29p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) echo "Unknown argument: $arg"; exit 1 ;;
    esac
done

step() { printf "\n\033[1;35m> %s\033[0m\n" "$1"; }
ok()   { printf "  \033[32m+ %s\033[0m\n" "$1"; }
warn() { printf "  \033[33m! %s\033[0m\n" "$1"; }
info() { printf "  \033[36mi %s\033[0m\n" "$1"; }

# --- Load .env (same reader as updAppStore.sh) -----------------------------

if [ -f "$ENV_FILE" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%$'\r'}"
        [[ "$line" =~ ^[A-Z_][A-Z0-9_]*= ]] || continue
        key="${line%%=*}"
        value="${line#*=}"
        value="${value#\"}"; value="${value%\"}"
        value="${value#\'}"; value="${value%\'}"
        export "$key=$value"
    done < "$ENV_FILE"
fi

# The Node scripts expect DEEPL_AUTH_KEY; the .env holds DEEPL_API_KEY.
if [ -n "${DEEPL_API_KEY:-}" ] && [ -z "${DEEPL_AUTH_KEY:-}" ]; then
    export DEEPL_AUTH_KEY="$DEEPL_API_KEY"
fi

# --- 1. Translate ----------------------------------------------------------

if [ "$TRANSLATE" = true ]; then
    step "Translating screenshot copy"
    if [ -z "${DEEPL_AUTH_KEY:-}" ]; then
        warn "No DeepL key (DEEPL_API_KEY in $ENV_FILE) — skipping translation."
        warn "Locales without a copy/<locale>.json fall back to en-US."
    else
        ARGS=()
        [ "$DRY_RUN" = true ] && ARGS+=("--dry-run")
        [ "$FORCE" = true ] && ARGS+=("--force")
        [ -n "$ONLY" ] && ARGS+=("--only=$ONLY")
        (cd "$SHOTS_DIR" && node translate-copy.mjs ${ARGS[@]+"${ARGS[@]}"})
    fi
fi

# --- 2. Render -------------------------------------------------------------

if [ "$RENDER" = true ]; then
    step "Rendering scenes"
    if ! command -v rsvg-convert >/dev/null 2>&1; then
        echo "Error: rsvg-convert not found. Install it with: brew install librsvg" >&2
        exit 1
    fi
    ARGS=()
    [ "$CLEAN" = true ] && ARGS+=("--clean")
    if [ -n "$ONLY" ]; then
        IFS=',' read -ra LOCALES <<< "$ONLY"
        ARGS+=("${LOCALES[@]}")
    fi
    "$SHOTS_DIR/render.sh" ${ARGS[@]+"${ARGS[@]}"}
fi

# --- 3. Upload -------------------------------------------------------------

if [ "$UPLOAD" = true ]; then
    step "Uploading to App Store Connect"
    if [ -z "${ASC_ISSUER_ID:-}" ] || [ -z "${ASC_KEY_ID:-}" ] || [ -z "${ASC_KEY_PATH:-}" ]; then
        warn "Missing ASC_ISSUER_ID / ASC_KEY_ID / ASC_KEY_PATH in $ENV_FILE — skipping upload."
        info "The PNGs are in $SHOTS_DIR/out and can be dropped in by hand."
        exit 0
    fi
    ARGS=()
    [ "$DRY_RUN" = true ] && ARGS+=("--dry-run")
    [ -n "$ONLY" ] && ARGS+=("--only=$ONLY")
    node "$SCRIPT_DIR/appstore-screenshots.mjs" ${ARGS[@]+"${ARGS[@]}"}
fi

step "Done"
