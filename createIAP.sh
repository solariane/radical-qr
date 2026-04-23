#!/usr/bin/env bash
#
# createIAP.sh — one-time (idempotent) creation of the Pro IAP in App Store Connect.
#
# Reads credentials from ../.env and the IAP definition from appstore/iap/pro.json.
# Safe to run twice — the Node script PATCHes instead of POSTing if the IAP exists.
#
# Usage:
#   ./createIAP.sh                # create / update
#   ./createIAP.sh --dry-run      # show what would happen
#   ./createIAP.sh --iap=path     # point at an alternate IAP json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"

if [ -f "$ENV_FILE" ]; then
    # `|| [ -n "$line" ]` picks up the last line even when the file has no
    # trailing newline. Strips CRLF and surrounding single/double quotes.
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

if [ -z "${ASC_ISSUER_ID:-}" ] || [ -z "${ASC_KEY_ID:-}" ] || [ -z "${ASC_KEY_PATH:-}" ]; then
    echo "Error: ASC credentials not set."
    echo "  Populate $ENV_FILE with ASC_ISSUER_ID, ASC_KEY_ID, ASC_KEY_PATH."
    echo "  See appstore/SETUP.md step 5 for how to generate the API key."
    exit 1
fi

node "$SCRIPT_DIR/appstore-iap-create.mjs" "$@"
