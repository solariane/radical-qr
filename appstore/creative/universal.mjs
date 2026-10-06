/**
 * universal.mjs — « Universal Creative Asset » de l'App Store (iOS 27+),
 * 5244 × 2950 (16:9). Un seul visuel, recadré par l'App Store pour l'en-tête
 * de la fiche (2,33:1, bandeau) et pour les résultats de recherche (3:2).
 * Même dispositif que cleanUpPhoneNumbers/appstore/creative/.
 *
 * Aucun texte : le visuel sert les 10 fiches tel quel, et Apple n'y veut ni
 * prix ni promesse. Variante « styles » : l'app en trois temps, de gauche à
 * droite — cinq contenus reconnus → un QR code élégant, avec le logo au
 * centre → trois styles différents. La variante « privacy » est dans
 * universal-privacy.mjs ; ce qu'elles partagent est dans lib.mjs.
 *
 *   node universal.mjs   →  out/universal.svg
 *   ./render.sh          →  out/universal.jpg (+ aperçus des deux recadrages)
 */

import { renderQR } from "../screenshots/lib/qr-svg.mjs";
import { cx, cy, white, inputColumn, qrCard, writeSvg } from "./lib.mjs";

const card = 1500;
const inputs = inputColumn({ x: cx - 1360, lineEnd: cx - card / 2 - 70 });
const centre = qrCard({ card });

// --- Droite : trois styles, le même contenu -----------------------------------

const tile = 400;
const tileRadius = 56;
const tileX = cx + 1360 - tile / 2;
const tileGap = 480;
const styles = [
  { color: "#000000", roundness: 0, eyeStyle: "square", eyeScale: 1 },
  { gradient: { start: "#2563EB", end: "#06B6D4", angle: 135 }, roundness: 0.3, eyeStyle: "rounded", eyeScale: 0.9 },
  { gradient: { start: "#F97316", end: "#EC4899", angle: 135 }, roundness: 1.0, eyeStyle: "dot", eyeScale: 0.85 },
];
const t0 = cy - (tileGap * (styles.length - 1)) / 2;

const tiles = styles.map((style, i) => {
  const y = t0 + i * tileGap - tile / 2;
  const inner = tile - 60;
  const qr = renderQR({
    content: "radicalsolution.com",
    size: inner,
    errorCorrection: "L",
    gradientId: `tile${i}`,
    ...style,
  });
  return `
    <g filter="url(#shadow)">
      <rect x="${tileX}" y="${y}" width="${tile}" height="${tile}" rx="${tileRadius}" fill="${white}"/>
    </g>
    <g transform="translate(${tileX + 30} ${y + 30})">${qr}</g>`;
}).join("");

writeSvg("universal", inputs.defs + centre.defs, inputs.body + tiles + centre.body);
