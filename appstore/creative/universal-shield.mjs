/**
 * universal-shield.mjs — la combinaison des deux variantes du visuel
 * universel (voir universal.mjs pour le format et la zone sûre).
 *
 * Les cinq contenus entrent dans le bouclier qui contient la carte QR, le
 * cadenas le scelle, et les trois styles restent à droite : ce que l'app
 * fait, et ce qu'elle ne fait pas de vos données, sur une seule image.
 *
 *   node universal-shield.mjs   →  out/universal-shield.svg
 */

import { cx, shield, inputColumn, qrCard, styleTiles, writeSvg } from "./lib.mjs";

const guard = shield();
const centre = qrCard({ y: guard.cardY, card: 1060, radius: 90, qr: 880, logo: 220 });
const inputs = inputColumn({ x: cx - 1360, lineEnd: cx - guard.hw - 60, converge: 0.3 });
const tiles = styleTiles();

writeSvg(
  "universal-shield",
  inputs.defs + guard.defs + centre.defs,
  inputs.body + tiles + guard.outline + centre.body + guard.lock,
);
