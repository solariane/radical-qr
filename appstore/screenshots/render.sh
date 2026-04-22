#!/usr/bin/env bash
# Renders every scene in scenes/ to SVG and PNG under out/.
# iPhone scenes land at 1290×2796; Mac scenes land at 2880×1800.
# Usage:
#   ./render.sh [locale]   (default: en-US)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOCALE="${1:-en-US}"
OUT="$SCRIPT_DIR/out"

mkdir -p "$OUT"

# Run every scene script so SVGs are regenerated
for scene in "$SCRIPT_DIR"/scenes/*.mjs; do
    node "$scene" "$LOCALE"
done

echo ""
echo "Converting iPhone SVGs → PNG (1290×2796)..."
for svg in "$OUT"/*-iphone-*-"$LOCALE".svg; do
    [ -f "$svg" ] || continue
    png="${svg%.svg}.png"
    rsvg-convert -w 1290 -h 2796 "$svg" -o "$png"
    echo "  $(basename "$png")"
done

echo ""
echo "Converting Mac SVGs → PNG (2880×1800)..."
for svg in "$OUT"/*-mac-"$LOCALE".svg; do
    [ -f "$svg" ] || continue
    png="${svg%.svg}.png"
    rsvg-convert -w 2880 -h 1800 "$svg" -o "$png"
    echo "  $(basename "$png")"
done

echo ""
echo "Done. See $OUT"
