#!/usr/bin/env bash
# Renders every scene in scenes/ to SVG, then rasterises to the sizes App Store
# Connect accepts.
#
# Usage:
#   ./render.sh                 # every locale that has a copy/<locale>.json
#   ./render.sh fr-FR           # one locale
#   ./render.sh --clean         # drop out/ first, then render everything
#
# The 6.5" PNG is the 6.9" drawing at legacy Pro Max dimensions, and it is named
# `-iphone-6.5-<locale>.png` so that appstore-screenshots.mjs can match it: that
# script keys on the display-type suffix and on the locale being last.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$SCRIPT_DIR/out"
COPY_DIR="$SCRIPT_DIR/copy"

if ! command -v rsvg-convert >/dev/null 2>&1; then
    echo "Error: rsvg-convert not found. Install it with: brew install librsvg" >&2
    exit 1
fi

CLEAN=0
LOCALES=()
for arg in "$@"; do
    case "$arg" in
        --clean) CLEAN=1 ;;
        -*) echo "Unknown option: $arg" >&2; exit 1 ;;
        *) LOCALES+=("$arg") ;;
    esac
done

# No locale given: render every language that has copy for it.
if [ ${#LOCALES[@]} -eq 0 ]; then
    while IFS= read -r file; do
        LOCALES+=("$(basename "$file" .json)")
    done < <(find "$COPY_DIR" -maxdepth 1 -name '*.json' | sort)
fi

if [ "$CLEAN" -eq 1 ]; then
    echo "Clearing $OUT"
    rm -rf "$OUT"
fi
mkdir -p "$OUT"

for LOCALE in "${LOCALES[@]}"; do
    echo ""
    echo "=== $LOCALE ==="

    for scene in "$SCRIPT_DIR"/scenes/*.mjs; do
        node "$scene" "$LOCALE"
    done

    echo "  iPhone → 6.9\" (1290×2796) + 6.5\" (1284×2778)"
    for svg in "$OUT"/*-iphone-6.9-"$LOCALE".svg; do
        [ -f "$svg" ] || continue
        base="$(basename "$svg" .svg)"
        rsvg-convert -w 1290 -h 2796 "$svg" -o "$OUT/${base}.png"
        rsvg-convert -w 1284 -h 2778 "$svg" -o "$OUT/${base/-iphone-6.9-/-iphone-6.5-}.png"
    done

    echo "  iPad → 2064×2752"
    for svg in "$OUT"/*-ipad-"$LOCALE".svg; do
        [ -f "$svg" ] || continue
        rsvg-convert -w 2064 -h 2752 "$svg" -o "${svg%.svg}.png"
    done

    echo "  Mac → 2880×1800"
    for svg in "$OUT"/*-mac-"$LOCALE".svg; do
        [ -f "$svg" ] || continue
        rsvg-convert -w 2880 -h 1800 "$svg" -o "${svg%.svg}.png"
    done
done

echo ""
echo "Done — $(find "$OUT" -name '*.png' | wc -l | tr -d ' ') PNG in $OUT"
