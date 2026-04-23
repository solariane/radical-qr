/**
 * p03-customization-ipad.mjs — QR + full customization panel side-by-side.
 */

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { renderQR } from "../lib/qr-svg.mjs";
import {
  IPAD_CANVAS, IPAD, IPAD_SCREEN, IPAD_CONTENT, IPAD_COLORS, IPAD_FONT,
  ipadSvgShell, ipadShell, ipadContentBackground, ipadHeadline, ipadSubtitle, escapeXML,
} from "../lib/ipad-frame.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.resolve(__dirname, "../out");
const LOCALE = process.argv[2] || "en-US";

const COPY = {
  "en-US": {
    headline: ["Your style.", "Your codes."],
    subtitle: ["Colors, gradients, rounded eyes —", "independent controls."],
    appTitle: "Customization",
    style: "Style", colors: "Colors", shape: "Shape",
    modules: "Modules", eyes: "Eyes", eyeSize: "Eye Size",
    sharp: "Sharp", slight: "Slight", rounded: "Rounded", circular: "Circular",
    compact: "Compact", medium: "Medium", full: "Full",
    solid: "Solid", gradient: "Gradient",
  },
  "fr-FR": {
    headline: ["Votre style.", "Vos codes."],
    subtitle: ["Couleurs, dégradés, yeux arrondis —", "réglages indépendants."],
    appTitle: "Personnalisation",
    style: "Style", colors: "Couleurs", shape: "Forme",
    modules: "Modules", eyes: "Yeux", eyeSize: "Taille yeux",
    sharp: "Net", slight: "Léger", rounded: "Arrondi", circular: "Rond",
    compact: "Compact", medium: "Moyen", full: "Plein",
    solid: "Uni", gradient: "Dégradé",
  },
};
const L = COPY[LOCALE] ?? COPY["en-US"];

const PAD_X = 48;
const APP_X = IPAD_CONTENT.x + PAD_X;
const APP_W = IPAD_CONTENT.w - PAD_X * 2;

// QR card
const QR_SIZE = 540;
const QR_CARD_W = QR_SIZE + 80;
const QR_CARD_H = QR_SIZE + 80;
const QR_CARD_X = IPAD_CONTENT.x + (IPAD_CONTENT.w - QR_CARD_W) / 2;
const QR_CARD_Y = IPAD_CONTENT.y + 170;

const qrSvg = renderQR({
  content: "https://radicalsolution.com/radical-qr",
  size: QR_SIZE,
  roundness: 0.6,
  eyeRoundness: 1.0,
  eyeScale: 0.85,
  gradient: { start: "#3b82f6", end: "#38c8d5", angle: 135 },
  background: "#ffffff",
  errorCorrection: "M",
  gradientId: "ipadCustQr",
});

// Customization panel
const PANEL_X = APP_X;
const PANEL_Y = QR_CARD_Y + QR_CARD_H + 40;
const PANEL_W = APP_W;
const PANEL_H = 520;

// Swatches
const swatches = [
  { type: "solid", c: "#000000" },
  { type: "solid", c: "#1e3a5f" },
  { type: "solid", c: "#2d5a3d" },
  { type: "grad", c1: "#667eea", c2: "#764ba2" },
  { type: "grad", c1: "#3b82f6", c2: "#38c8d5", selected: true },
  { type: "grad", c1: "#f97316", c2: "#ec4e8d" },
];

function renderSwatches(x, y, size = 56, gap = 18) {
  return swatches.map((s, i) => {
    const cx = x + i * (size + gap) + size / 2;
    const cy = y + size / 2;
    const stroke = s.selected ? `stroke="#1c1c20" stroke-width="3"` : "";
    if (s.type === "solid") {
      return `<circle cx="${cx}" cy="${cy}" r="${size / 2}" fill="${s.c}" ${stroke}/>`;
    }
    const gid = `ipadSw${i}`;
    return `
      <defs><linearGradient id="${gid}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${s.c1}"/><stop offset="1" stop-color="${s.c2}"/></linearGradient></defs>
      <circle cx="${cx}" cy="${cy}" r="${size / 2}" fill="url(#${gid})" ${stroke}/>
    `;
  }).join("");
}

function presetRow(y, label, options, selectedIdx, startX) {
  const rowH = 44;
  const pillW = 120;
  const gap = 12;
  const pills = options.map((opt, i) => {
    const x = startX + (pillW + gap) * i;
    const selected = i === selectedIdx;
    const bg = selected ? IPAD_COLORS.qrGradientStart : "#eeedf4";
    const fg = selected ? "#ffffff" : "#1c1c20";
    return `
      <rect x="${x}" y="${y}" width="${pillW}" height="${rowH}" rx="14" ry="14" fill="${bg}"/>
      <text x="${x + pillW / 2}" y="${y + rowH / 2 + 7}" text-anchor="middle" font-size="18" font-weight="${selected ? "600" : "500"}" fill="${fg}" font-family="${IPAD_FONT}">${escapeXML(opt)}</text>
    `;
  }).join("");
  return `
    <text x="${PANEL_X + 28}" y="${y + rowH / 2 + 7}" font-size="18" font-weight="500" fill="#1c1c20" font-family="${IPAD_FONT}">${escapeXML(label)}</text>
    ${pills}
  `;
}

const SEC_Y_STYLE = PANEL_Y + 32;
const SEC_Y_COLORS = PANEL_Y + 130;
const SEC_Y_SHAPE = PANEL_Y + 280;

const inner = `
  ${ipadHeadline(L.headline)}

  ${ipadShell({ activeSidebar: "generator" })}
  ${ipadContentBackground()}

  <!-- App header -->
  <text x="${IPAD_CONTENT.x + 48}" y="${IPAD_CONTENT.y + 100}" font-size="42" font-weight="600" fill="#ffffff" font-family="${IPAD_FONT}">${escapeXML(L.appTitle)}</text>

  <!-- QR card -->
  <g filter="url(#ipadCardShadow)">
    <rect x="${QR_CARD_X}" y="${QR_CARD_Y}" width="${QR_CARD_W}" height="${QR_CARD_H}" rx="22" ry="22" fill="#ffffff"/>
    <g transform="translate(${QR_CARD_X + 40} ${QR_CARD_Y + 40})">${qrSvg}</g>
  </g>

  <!-- Customization panel -->
  <g filter="url(#ipadCardShadow)">
    <rect x="${PANEL_X}" y="${PANEL_Y}" width="${PANEL_W}" height="${PANEL_H}" rx="22" ry="22" fill="#ffffff"/>
  </g>

  <!-- Style picker -->
  <g>
    <text x="${PANEL_X + 28}" y="${SEC_Y_STYLE + 18}" font-size="15" font-weight="700" fill="#6a6a72" letter-spacing="1" font-family="${IPAD_FONT}">${escapeXML(L.style.toUpperCase())}</text>
    <rect x="${PANEL_X + 28}" y="${SEC_Y_STYLE + 38}" width="260" height="48" rx="12" ry="12" fill="#eeedf4"/>
    <rect x="${PANEL_X + 28 + 130}" y="${SEC_Y_STYLE + 38}" width="130" height="48" rx="12" ry="12" fill="${IPAD_COLORS.qrGradientStart}"/>
    <text x="${PANEL_X + 28 + 65}" y="${SEC_Y_STYLE + 38 + 30}" text-anchor="middle" font-size="18" fill="#1c1c20" font-family="${IPAD_FONT}">${escapeXML(L.solid)}</text>
    <text x="${PANEL_X + 28 + 195}" y="${SEC_Y_STYLE + 38 + 30}" text-anchor="middle" font-size="18" font-weight="600" fill="#ffffff" font-family="${IPAD_FONT}">${escapeXML(L.gradient)}</text>
  </g>

  <!-- Colors -->
  <g>
    <text x="${PANEL_X + 28}" y="${SEC_Y_COLORS + 18}" font-size="15" font-weight="700" fill="#6a6a72" letter-spacing="1" font-family="${IPAD_FONT}">${escapeXML(L.colors.toUpperCase())}</text>
    ${renderSwatches(PANEL_X + 28, SEC_Y_COLORS + 38)}
  </g>

  <!-- Shape -->
  <g>
    <text x="${PANEL_X + 28}" y="${SEC_Y_SHAPE + 18}" font-size="15" font-weight="700" fill="#6a6a72" letter-spacing="1" font-family="${IPAD_FONT}">${escapeXML(L.shape.toUpperCase())}</text>
    ${presetRow(SEC_Y_SHAPE + 48, L.modules, [L.sharp, L.slight, L.rounded, L.circular], 2, PANEL_X + 180)}
    ${presetRow(SEC_Y_SHAPE + 108, L.eyes, [L.sharp, L.slight, L.rounded, L.circular], 3, PANEL_X + 180)}
    ${presetRow(SEC_Y_SHAPE + 168, L.eyeSize, [L.compact, L.medium, L.full], 1, PANEL_X + 180)}
  </g>

  ${ipadSubtitle(L.subtitle)}
`;

fs.mkdirSync(OUT, { recursive: true });
const filename = `p03-customization-ipad-${LOCALE}.svg`;
fs.writeFileSync(path.join(OUT, filename), ipadSvgShell(inner));
console.log("wrote", path.relative(process.cwd(), path.join(OUT, filename)));
