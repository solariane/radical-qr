#!/usr/bin/env bash
# Rend chaque variante du visuel universel en PNG puis en JPEG (sans couche
# alpha, que l'App Store refuse), et produit deux aperçus des recadrages.
#   ./render.sh                     # les deux variantes
#   ./render.sh universal-privacy   # une seule
set -euo pipefail
cd "$(dirname "$0")"
VARIANTS=("$@")
[ ${#VARIANTS[@]} -eq 0 ] && VARIANTS=(universal universal-privacy)
for v in "${VARIANTS[@]}"; do
  node "$v.mjs"
  rsvg-convert -w 5244 -h 2950 "out/$v.svg" -o "out/$v.png"
  sips -s format jpeg -s formatOptions 92 "out/$v.png" --out "out/$v.jpg" >/dev/null
  # Aperçus : bandeau d'en-tête (2,33:1) et résultats de recherche (3:2), centrés.
  sips -c 2248 5244 "out/$v.png" --out "out/$v-preview-header.png" >/dev/null
  sips -c 2950 4425 "out/$v.png" --out "out/$v-preview-search.png" >/dev/null
  sips -g pixelWidth -g pixelHeight -g hasAlpha "out/$v.jpg" | tail -3 | tr '\n' ' '; echo " ← $v.jpg"
done
