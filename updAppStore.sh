#!/usr/bin/env bash
#
# updAppStore.sh - One-command App Store metadata workflow for Radical QR
#
# Steps:
#   1. Translate empty / stale target locales via DeepL (hash-based invalidation)
#   2. Push localized metadata to App Store Connect's current EDIT version
#
# Requirements:
#   - DEEPL_API_KEY in ../.env (for translation)
#   - ASC_ISSUER_ID, ASC_KEY_ID, ASC_KEY_PATH in ../.env (for push)
#   - Node.js
#
# Usage:
#   ./updAppStore.sh                  # translate + push
#   ./updAppStore.sh --translate-only # translate, don't push
#   ./updAppStore.sh --push-only      # push, don't translate
#   ./updAppStore.sh --dry-run        # translate + push as dry-run (no API writes)
#   ./updAppStore.sh --force          # re-translate even if hash matches
#   ./updAppStore.sh --only=fr-FR,de-DE  # restrict to specific locales

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"

TRANSLATE_SCRIPT="$SCRIPT_DIR/appstore-translate.mjs"
PUSH_SCRIPT="$SCRIPT_DIR/appstore-push.mjs"

TRANSLATE=true
PUSH=true
DRY_RUN=false
FORCE=false
ONLY=""

for arg in "$@"; do
    case "$arg" in
        --translate-only) PUSH=false ;;
        --push-only)      TRANSLATE=false ;;
        --dry-run)        DRY_RUN=true ;;
        --force)          FORCE=true ;;
        --only=*)         ONLY="${arg#--only=}" ;;
        --help|-h)
            echo "Usage: $0 [--translate-only|--push-only] [--dry-run] [--force] [--only=<locale>[,<locale>...]]"
            exit 0
            ;;
        *) echo "Unknown argument: $arg"; exit 1 ;;
    esac
done

step() { printf "\n\033[1;35m> %s\033[0m\n" "$1"; }
ok()   { printf "  \033[32m+ %s\033[0m\n" "$1"; }
warn() { printf "  \033[33m! %s\033[0m\n" "$1"; }
info() { printf "  \033[36mi %s\033[0m\n" "$1"; }

# --- Load .env -------------------------------------------------------------

if [ -f "$ENV_FILE" ]; then
    # Export every uncommented KEY=VALUE line so the node scripts pick them up.
    # `|| [ -n "$line" ]` catches the last line when the file has no trailing
    # newline. Strips CRLF line endings and surrounding single/double quotes.
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

# Map DEEPL_API_KEY → DEEPL_AUTH_KEY (the name the Node scripts expect).
if [ -n "${DEEPL_API_KEY:-}" ] && [ -z "${DEEPL_AUTH_KEY:-}" ]; then
    export DEEPL_AUTH_KEY="$DEEPL_API_KEY"
fi

# Auto-detect free vs paid endpoint from key suffix.
DEEPL_API_BASE="https://api.deepl.com"
if [[ "${DEEPL_AUTH_KEY:-}" == *":fx" ]]; then
    DEEPL_API_BASE="https://api-free.deepl.com"
fi

# --- Step 1: translate -----------------------------------------------------

if [ "$TRANSLATE" = true ]; then
    step "Translating missing / stale App Store metadata via DeepL..."

    if [ -z "${DEEPL_AUTH_KEY:-}" ]; then
        warn "DEEPL_AUTH_KEY not set — skipping translation step."
    else
        TRANSLATE_ARGS=(--source=EN --api-base="$DEEPL_API_BASE")
        [ "$FORCE" = true ]    && TRANSLATE_ARGS+=(--force)
        [ -n "$ONLY" ]         && TRANSLATE_ARGS+=(--only="$ONLY")
        node "$TRANSLATE_SCRIPT" "${TRANSLATE_ARGS[@]}"
        ok "Translation pass complete."
    fi
fi

# --- Step 2: push ----------------------------------------------------------

if [ "$PUSH" = true ]; then
    step "Pushing metadata to App Store Connect..."

    if [ -z "${ASC_ISSUER_ID:-}" ] || [ -z "${ASC_KEY_ID:-}" ] || [ -z "${ASC_KEY_PATH:-}" ]; then
        warn "ASC credentials not set (ASC_ISSUER_ID / ASC_KEY_ID / ASC_KEY_PATH). Skipping push."
        info "Add them to $ENV_FILE to enable."
    else
        PUSH_ARGS=()
        [ "$DRY_RUN" = true ] && PUSH_ARGS+=(--dry-run)
        [ -n "$ONLY" ]        && PUSH_ARGS+=(--only="$ONLY")
        # `${arr[@]+"${arr[@]}"}` safely expands to nothing when the array is
        # empty. Needed because `set -u` treats an empty array expansion as an
        # unbound variable on bash 3.2 (macOS default).
        node "$PUSH_SCRIPT" ${PUSH_ARGS[@]+"${PUSH_ARGS[@]}"}
        ok "Push pass complete."
    fi
fi

step "App Store metadata workflow complete."
