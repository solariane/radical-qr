#!/usr/bin/env bash
# Rend le visuel universel en PNG puis en JPEG (sans couche alpha, que
# l'App Store refuse), et produit deux aperçus des recadrages.
set -euo pipefail
cd "$(dirname "$0")"
node universal.mjs
rsvg-convert -w 5244 -h 2950 out/universal.svg -o out/universal.png
sips -s format jpeg -s formatOptions 92 out/universal.png --out out/universal.jpg >/dev/null
# Aperçus : bandeau d'en-tête (2,33:1) et résultats de recherche (3:2), centrés.
sips -c 2248 5244 out/universal.png --out out/preview-header.png >/dev/null
sips -c 2950 4425 out/universal.png --out out/preview-search.png >/dev/null
sips -g pixelWidth -g pixelHeight -g hasAlpha out/universal.jpg | tail -3
