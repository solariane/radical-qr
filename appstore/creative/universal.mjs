/**
 * universal.mjs — « Universal Creative Asset » de l'App Store (iOS 27+),
 * 5244 × 2950 (16:9). Un seul visuel, recadré par l'App Store pour l'en-tête
 * de la fiche (2,33:1, bandeau) et pour les résultats de recherche (3:2).
 * Même dispositif que cleanUpPhoneNumbers/appstore/creative/.
 *
 * Aucun texte : le visuel sert les 10 fiches tel quel, et Apple n'y veut ni
 * prix ni promesse. Il dit l'app en trois temps, de gauche à droite :
 * cinq contenus reconnus (lien, Wi-Fi, événement, contact, lieu) → un QR
 * code élégant, avec le logo au centre → trois styles différents.
 *
 * Zone sûre : l'intersection des deux recadrages centrés — 4425 × 2248 px —,
 * moins une marge en bas pour l'icône, le nom et le bouton « Obtenir » que
 * l'App Store pose par-dessus l'en-tête. D'où le centre optique à y = 1300.
 *
 *   node universal.mjs   →  out/universal.svg
 *   ./render.sh          →  out/universal.jpg (+ aperçus des deux recadrages)
 */

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { renderQR } from "../screenshots/lib/qr-svg.mjs";
import { symbol } from "../screenshots/lib/symbols.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(__dirname, "out");
const ICON = path.resolve(__dirname, "../../Radical QR/Assets.xcassets/AppIcon.appiconset/icon-1024.png");

const W = 5244, H = 2950;
const cx = W / 2;
const cy = 1300;

// Le dégradé de l'app (CLAUDE.md), et celui du QR du hero des captures.
const BG = { start: "#667eea", end: "#764ba2" };
const QR_GRADIENT = { start: "#4D33D9", end: "#8C3BBF", angle: 135 };

// --- Centre : la carte blanche et le QR avec logo -----------------------------

const card = 1500;
const cardRadius = 120;                 // les 24 pt de l'app, à l'échelle
const qrSize = 1240;
const qrX = cx - qrSize / 2, qrY = cy - qrSize / 2;

const mainQR = renderQR({
  // Court : une URL longue en correction H donne 45 modules de côté, un
  // grain trop fin pour un bandeau. Ici 33, et le logo laisse le code lisible.
  content: "https://radicalsolution.com",
  size: qrSize,
  roundness: 0.6,
  eyeStyle: "leaf",
  eyeScale: 0.9,
  gradient: QR_GRADIENT,
  errorCorrection: "H",                 // H : le logo peut couvrir le centre
  gradientId: "mainQR",
});

// Logo incrusté : l'icône de l'app, sur une zone blanche comme l'exporteur la pose.
const icon = fs.readFileSync(ICON).toString("base64");
const logo = 300;
const logoPad = 36;
const logoRadius = logo * 0.2237;

// --- Gauche : ce que l'app reconnaît ------------------------------------------

const chipR = 118;
const chipX = cx - 1360;
const chipGap = 300;
const glyph = 110;
const white = "#ffffff";

function wifiGlyph(x, y, s) {
  const r = [0.95, 0.62, 0.3].map((k) => s * k);
  const arcs = r.map((rr) => {
    const a = Math.PI / 4;
    const x1 = x - rr * Math.sin(a), y1 = y + s * 0.35 - rr * Math.cos(a);
    const x2 = x + rr * Math.sin(a), y2 = y1;
    return `<path d="M ${x1} ${y1} A ${rr} ${rr} 0 0 1 ${x2} ${y2}" stroke="${white}" stroke-width="${s * 0.17}" stroke-linecap="round" fill="none"/>`;
  }).join("");
  return `${arcs}<circle cx="${x}" cy="${y + s * 0.35}" r="${s * 0.11}" fill="${white}"/>`;
}

function personGlyph(x, y, s) {
  return `<circle cx="${x}" cy="${y - s * 0.28}" r="${s * 0.27}" fill="${white}"/>
    <path d="M ${x - s * 0.62} ${y + s * 0.62} a ${s * 0.62} ${s * 0.55} 0 0 1 ${s * 1.24} 0 Z" fill="${white}"/>`;
}

function pinGlyph(x, y, s) {
  const r = s * 0.42;
  const top = y - s * 0.3;
  return `<path d="M ${x} ${y + s * 0.62} C ${x - r * 0.3} ${y + s * 0.2}, ${x - r} ${top + r * 0.9}, ${x - r} ${top}
      A ${r} ${r} 0 0 1 ${x + r} ${top}
      C ${x + r} ${top + r * 0.9}, ${x + r * 0.3} ${y + s * 0.2}, ${x} ${y + s * 0.62} Z" fill="${white}"/>
    <circle cx="${x}" cy="${top}" r="${r * 0.42}" fill="${BG.start}"/>`;
}

const inputs = [
  (x, y) => symbol("link", x, y, glyph, white, "bold"),
  (x, y) => wifiGlyph(x, y, glyph * 0.62),
  (x, y) => symbol("calendar", x, y, glyph, white, "bold"),
  (x, y) => personGlyph(x, y, glyph * 0.7),
  (x, y) => pinGlyph(x, y, glyph * 0.72),
];
const y0 = cy - (chipGap * (inputs.length - 1)) / 2;

const chips = inputs.map((draw, i) => {
  const y = y0 + i * chipGap;
  // Un filet qui s'efface vers la carte : « tout cela devient ceci ».
  const lineEnd = cx - card / 2 - 70;
  return `
    <line x1="${chipX + chipR + 40}" y1="${y}" x2="${lineEnd}" y2="${cy + (y - cy) * 0.18}"
          stroke="url(#flow)" stroke-width="10" stroke-linecap="round"/>
    <circle cx="${chipX}" cy="${y}" r="${chipR}" fill="${white}" fill-opacity="0.18"/>
    <circle cx="${chipX}" cy="${y}" r="${chipR}" fill="none" stroke="${white}" stroke-opacity="0.35" stroke-width="5"/>
    ${draw(chipX, y)}`;
}).join("");

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

// --- Assemblage ---------------------------------------------------------------

const svg = `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
     width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="${W}" y2="${H}" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="${BG.start}"/>
      <stop offset="1" stop-color="${BG.end}"/>
    </linearGradient>
    <radialGradient id="glow" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="#ffffff" stop-opacity="0.22"/>
      <stop offset="1" stop-color="#ffffff" stop-opacity="0"/>
    </radialGradient>
    <!-- userSpaceOnUse : la ligne du milieu est horizontale, et un dégradé
         relatif à sa boîte englobante (hauteur nulle) ne se dessine pas. -->
    <linearGradient id="flow" x1="${chipX + chipR + 40}" y1="0" x2="${cx - card / 2 - 70}" y2="0" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#ffffff" stop-opacity="0.45"/>
      <stop offset="1" stop-color="#ffffff" stop-opacity="0"/>
    </linearGradient>
    <clipPath id="logoClip">
      <rect x="${cx - logo / 2}" y="${cy - logo / 2}" width="${logo}" height="${logo}" rx="${logoRadius}" ry="${logoRadius}"/>
    </clipPath>
    <filter id="shadow" x="-30%" y="-30%" width="160%" height="160%">
      <feGaussianBlur in="SourceAlpha" stdDeviation="40"/>
      <feOffset dy="30"/>
      <feComponentTransfer><feFuncA type="linear" slope="0.3"/></feComponentTransfer>
      <feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
  </defs>
  <rect width="${W}" height="${H}" fill="url(#bg)"/>
  <circle cx="${cx}" cy="${cy}" r="1600" fill="url(#glow)"/>
  ${chips}
  ${tiles}
  <g filter="url(#shadow)">
    <rect x="${cx - card / 2}" y="${cy - card / 2}" width="${card}" height="${card}" rx="${cardRadius}" fill="${white}"/>
  </g>
  <g transform="translate(${qrX} ${qrY})">${mainQR}</g>
  <rect x="${cx - logo / 2 - logoPad}" y="${cy - logo / 2 - logoPad}" width="${logo + logoPad * 2}" height="${logo + logoPad * 2}"
        rx="${logoRadius + logoPad}" fill="${white}"/>
  <image x="${cx - logo / 2}" y="${cy - logo / 2}" width="${logo}" height="${logo}"
         clip-path="url(#logoClip)" xlink:href="data:image/png;base64,${icon}"/>
</svg>`;

fs.mkdirSync(OUT, { recursive: true });
fs.writeFileSync(path.join(OUT, "universal.svg"), svg);
console.log("wrote out/universal.svg");
