/**
 * lib.mjs — ce que les variantes du visuel universel partagent : la toile
 * 5244 × 2950, le fond de l'app, les pastilles des cinq contenus reconnus,
 * le QR central avec le logo, et l'écriture du SVG.
 *
 * Zone sûre : l'intersection des deux recadrages centrés — 4425 × 2248 px —,
 * moins une marge en bas pour l'icône, le nom et le bouton « Obtenir » que
 * l'App Store pose par-dessus l'en-tête. D'où le centre optique à y = 1300.
 */

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { renderQR } from "../screenshots/lib/qr-svg.mjs";
import { symbol } from "../screenshots/lib/symbols.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(__dirname, "out");
const ICON = path.resolve(__dirname, "../../Radical QR/Assets.xcassets/AppIcon.appiconset/icon-1024.png");

export const W = 5244, H = 2950;
export const cx = W / 2;
export const cy = 1300;
export const white = "#ffffff";

// Le dégradé de l'app (CLAUDE.md), et celui du QR du hero des captures.
export const BG = { start: "#667eea", end: "#764ba2" };
export const QR_GRADIENT = { start: "#4D33D9", end: "#8C3BBF", angle: 135 };

/** Fond, halo et ombre portée : les <defs> et les deux premiers calques. */
export function backdrop() {
  return `
    <linearGradient id="bg" x1="0" y1="0" x2="${W}" y2="${H}" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="${BG.start}"/>
      <stop offset="1" stop-color="${BG.end}"/>
    </linearGradient>
    <radialGradient id="glow" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="#ffffff" stop-opacity="0.22"/>
      <stop offset="1" stop-color="#ffffff" stop-opacity="0"/>
    </radialGradient>
    <filter id="shadow" x="-30%" y="-30%" width="160%" height="160%">
      <feGaussianBlur in="SourceAlpha" stdDeviation="40"/>
      <feOffset dy="30"/>
      <feComponentTransfer><feFuncA type="linear" slope="0.3"/></feComponentTransfer>
      <feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>`;
}

export function backgroundLayers() {
  return `
  <rect width="${W}" height="${H}" fill="url(#bg)"/>
  <circle cx="${cx}" cy="${cy}" r="1600" fill="url(#glow)"/>`;
}

// --- Les cinq contenus reconnus : lien, Wi-Fi, événement, contact, lieu ------

export function wifiGlyph(x, y, s) {
  const arcs = [0.95, 0.62, 0.3].map((k) => {
    const rr = s * k;
    const a = Math.PI / 4;
    const x1 = x - rr * Math.sin(a), y1 = y + s * 0.35 - rr * Math.cos(a);
    return `<path d="M ${x1} ${y1} A ${rr} ${rr} 0 0 1 ${x + rr * Math.sin(a)} ${y1}" stroke="${white}" stroke-width="${s * 0.17}" stroke-linecap="round" fill="none"/>`;
  }).join("");
  return `${arcs}<circle cx="${x}" cy="${y + s * 0.35}" r="${s * 0.11}" fill="${white}"/>`;
}

export function personGlyph(x, y, s) {
  return `<circle cx="${x}" cy="${y - s * 0.28}" r="${s * 0.27}" fill="${white}"/>
    <path d="M ${x - s * 0.62} ${y + s * 0.62} a ${s * 0.62} ${s * 0.55} 0 0 1 ${s * 1.24} 0 Z" fill="${white}"/>`;
}

export function pinGlyph(x, y, s, hole = BG.start) {
  const r = s * 0.42;
  const top = y - s * 0.3;
  return `<path d="M ${x} ${y + s * 0.62} C ${x - r * 0.3} ${y + s * 0.2}, ${x - r} ${top + r * 0.9}, ${x - r} ${top}
      A ${r} ${r} 0 0 1 ${x + r} ${top}
      C ${x + r} ${top + r * 0.9}, ${x + r * 0.3} ${y + s * 0.2}, ${x} ${y + s * 0.62} Z" fill="${white}"/>
    <circle cx="${x}" cy="${top}" r="${r * 0.42}" fill="${hole}"/>`;
}

export const CHIP_R = 118;
const GLYPH = 110;

export const INPUT_GLYPHS = [
  (x, y) => symbol("link", x, y, GLYPH, white, "bold"),
  (x, y) => wifiGlyph(x, y, GLYPH * 0.62),
  (x, y) => symbol("calendar", x, y, GLYPH, white, "bold"),
  (x, y) => personGlyph(x, y, GLYPH * 0.7),
  (x, y) => pinGlyph(x, y, GLYPH * 0.72),
];

/** Une pastille translucide, avec son glyphe. */
export function chip(x, y, draw, { fill = 0.18, stroke = 0.35 } = {}) {
  return `
    <circle cx="${x}" cy="${y}" r="${CHIP_R}" fill="${white}" fill-opacity="${fill}"/>
    <circle cx="${x}" cy="${y}" r="${CHIP_R}" fill="none" stroke="${white}" stroke-opacity="${stroke}" stroke-width="5"/>
    ${draw(x, y)}`;
}

/**
 * La colonne des cinq pastilles, et un filet par pastille qui s'efface vers
 * `lineEnd` : « tout cela devient ceci ». Le dégradé du filet est en
 * coordonnées absolues : la ligne du milieu est horizontale, et un dégradé
 * relatif à sa boîte englobante (hauteur nulle) ne se dessine pas.
 */
export function inputColumn({ x, gap = 300, lineEnd, converge = 0.18 }) {
  const y0 = cy - (gap * (INPUT_GLYPHS.length - 1)) / 2;
  const x1 = x + CHIP_R + 40;
  const defs = `
    <linearGradient id="flow" x1="${x1}" y1="0" x2="${lineEnd}" y2="0" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#ffffff" stop-opacity="0.45"/>
      <stop offset="1" stop-color="#ffffff" stop-opacity="0"/>
    </linearGradient>`;
  const body = INPUT_GLYPHS.map((draw, i) => {
    const y = y0 + i * gap;
    return `
    <line x1="${x1}" y1="${y}" x2="${lineEnd}" y2="${cy + (y - cy) * converge}"
          stroke="url(#flow)" stroke-width="10" stroke-linecap="round"/>
    ${chip(x, y, draw)}`;
  }).join("");
  return { defs, body };
}

// --- La carte blanche, le QR et le logo ---------------------------------------

/**
 * Court : une URL longue en correction H donne 45 modules de côté, un grain
 * trop fin pour un bandeau. Ici 33, et le logo laisse le code lisible.
 */
export function qrCard({ x = cx, y = cy, card = 1500, radius = 120, qr = 1240, logo = 300 } = {}) {
  const code = renderQR({
    content: "https://radicalsolution.com",
    size: qr,
    roundness: 0.6,
    eyeStyle: "leaf",
    eyeScale: 0.9,
    gradient: QR_GRADIENT,
    errorCorrection: "H",                 // H : le logo peut couvrir le centre
    gradientId: "mainQR",
  });
  const icon = fs.readFileSync(ICON).toString("base64");
  const logoPad = logo * 0.12;
  const logoRadius = logo * 0.2237;       // l'arrondi des icônes iOS
  const defs = `
    <clipPath id="logoClip">
      <rect x="${x - logo / 2}" y="${y - logo / 2}" width="${logo}" height="${logo}" rx="${logoRadius}" ry="${logoRadius}"/>
    </clipPath>`;
  const body = `
  <g filter="url(#shadow)">
    <rect x="${x - card / 2}" y="${y - card / 2}" width="${card}" height="${card}" rx="${radius}" fill="${white}"/>
  </g>
  <g transform="translate(${x - qr / 2} ${y - qr / 2})">${code}</g>
  <rect x="${x - logo / 2 - logoPad}" y="${y - logo / 2 - logoPad}" width="${logo + logoPad * 2}" height="${logo + logoPad * 2}"
        rx="${logoRadius + logoPad}" fill="${white}"/>
  <image x="${x - logo / 2}" y="${y - logo / 2}" width="${logo}" height="${logo}"
         clip-path="url(#logoClip)" xlink:href="data:image/png;base64,${icon}"/>`;
  return { defs, body };
}

// --- Trois styles, le même contenu --------------------------------------------

/** Une colonne de trois tuiles blanches, chacune avec le même code autrement habillé. */
export function styleTiles({ x = cx + 1360, gap = 480 } = {}) {
  const tile = 400;
  const tileRadius = 56;
  const tileX = x - tile / 2;
  const tileGap = gap;
  const styles = [
    { color: "#000000", roundness: 0, eyeStyle: "square", eyeScale: 1 },
    { gradient: { start: "#2563EB", end: "#06B6D4", angle: 135 }, roundness: 0.3, eyeStyle: "rounded", eyeScale: 0.9 },
    { gradient: { start: "#F97316", end: "#EC4899", angle: 135 }, roundness: 1.0, eyeStyle: "dot", eyeScale: 0.85 },
  ];
  const t0 = cy - (tileGap * (styles.length - 1)) / 2;

  return styles.map((style, i) => {
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
}

// --- Le bouclier et son cadenas ------------------------------------------------

/**
 * Un bouclier centré sur (cx, cy) : épaules arrondies, flancs qui se referment
 * en pointe, et un cadenas aux couleurs du QR sur la pointe. La carte vit dans
 * la partie haute, large ; `cardY` est le centre qui lui convient.
 */
export function shield({ sw = 1760, sh = 1720 } = {}) {
  const top = cy - sh / 2, bottom = cy + sh / 2, hw = sw / 2;
  const shoulder = sw * 0.14;
  const waist = cy - sh * 0.06;          // où les flancs quittent la verticale
  const path = `M ${cx - hw + shoulder} ${top}
    H ${cx + hw - shoulder}
    Q ${cx + hw} ${top} ${cx + hw} ${top + shoulder}
    V ${waist}
    C ${cx + hw} ${cy + sh * 0.42}, ${cx + sw * 0.17} ${bottom - sh * 0.09}, ${cx} ${bottom}
    C ${cx - sw * 0.17} ${bottom - sh * 0.09}, ${cx - hw} ${cy + sh * 0.42}, ${cx - hw} ${waist}
    V ${top + shoulder}
    Q ${cx - hw} ${top} ${cx - hw + shoulder} ${top} Z`;
  const lockR = 150;
  const lockY = bottom - 40;
  const defs = `
    <linearGradient id="lockFill" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="${QR_GRADIENT.start}"/><stop offset="1" stop-color="${QR_GRADIENT.end}"/>
    </linearGradient>`;
  const outline = `
  <path d="${path}" fill="${white}" fill-opacity="0.12" stroke="${white}" stroke-opacity="0.6" stroke-width="12" stroke-linejoin="round"/>`;
  const lock = `
  <g filter="url(#shadow)"><circle cx="${cx}" cy="${lockY}" r="${lockR}" fill="${white}"/></g>
  ${symbol("lock.fill", cx, lockY + 6, lockR * 1.1, "url(#lockFill)")}`;
  return { defs, outline, lock, hw, top, bottom, cardY: cy - 70 };
}

export function writeSvg(name, defs, body) {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
     width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
  <defs>${backdrop()}${defs}</defs>
  ${backgroundLayers()}
  ${body}
</svg>`;
  fs.mkdirSync(OUT, { recursive: true });
  fs.writeFileSync(path.join(OUT, `${name}.svg`), svg);
  console.log(`wrote out/${name}.svg`);
}
