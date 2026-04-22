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
    while IFS= read -r line; do
        if [[ "$line" =~ ^[A-Z_][A-Z0-9_]*= ]]; then
            export "$line"
        fi
    done < "$ENV_FILE"
fi

if [ -z "${ASC_ISSUER_ID:-}" ] || [ -z "${ASC_KEY_ID:-}" ] || [ -z "${ASC_KEY_PATH:-}" ]; then
    echo "Error: ASC credentials not set."
    echo "  Populate $ENV_FILE with ASC_ISSUER_ID, ASC_KEY_ID, ASC_KEY_PATH."
    echo "  See appstore/SETUP.md step 5 for how to generate the API key."
    exit 1
fi

node "$SCRIPT_DIR/appstore-iap-create.mjs" "$@"
