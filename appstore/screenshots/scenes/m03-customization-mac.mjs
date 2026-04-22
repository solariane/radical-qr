/**
 * m03-customization-mac.mjs — full customization panel side-by-side with the QR.
 * Uses the landscape Mac canvas to show everything at once.
 */

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { renderQR } from "../lib/qr-svg.mjs";
import {
  MAC_CANVAS, WINDOW, CONTENT, SIDEBAR, MAC_COLORS, MAC_FONT,
  macShell, macWindowShell, macHeadline, macSubtitle, escapeXML,
} from "../lib/mac-frame.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.resolve(__dirname, "../out");
const LOCALE = process.argv[2] || "en-US";

const COPY = {
  "en-US": {
    headline: ["Your style.", "Your codes."],
    subtitle: "Colors, gradients, rounded eyes — independent controls.",
    style: "Style", colors: "Colors", shape: "Shape",
    modules: "Modules", eyes: "Eyes", eyeSize: "Eye Size",
    sharp: "Sharp", slight: "Slight", rounded: "Rounded", circular: "Circular",
    compact: "Compact", medium: "Medium", full: "Full",
    solid: "Solid", gradient: "Gradient",
  },
  "fr-FR": {
    headline: ["Votre style.", "Vos codes."],
    subtitle: "Couleurs, dégradés, yeux arrondis — réglages indépendants.",
    style: "Style", colors: "Couleurs", shape: "Forme",
    modules: "Modules", eyes: "Yeux", eyeSize: "Taille yeux",
    sharp: "Net", slight: "Léger", rounded: "Arrondi", circular: "Rond",
    compact: "Compact", medium: "Moyen", full: "Plein",
    solid: "Uni", gradient: "Dégradé",
  },
};
const L = COPY[LOCALE] ?? COPY["en-US"];

// Layout: left = QR card, right = customization panel, both inside the content area.
const INNER_PAD_X = 40;
const INNER_PAD_Y = 160;
const COL_GAP = 40;

const innerX = CONTENT.x + INNER_PAD_X;
const innerY = CONTENT.y + INNER_PAD_Y;
const innerW = CONTENT.w - INNER_PAD_X * 2;
const innerH = CONTENT.h - INNER_PAD_Y - 60;

const QR_CARD_W = Math.round(innerW * 0.45);
const QR_CARD_H = innerH;
const QR_CARD_X = innerX;
const QR_CARD_Y = innerY;
const QR_SIZE = Math.min(QR_CARD_W - 80, QR_CARD_H - 80, 620);
const QR_X = QR_CARD_X + (QR_CARD_W - QR_SIZE) / 2;
const QR_Y = QR_CARD_Y + (QR_CARD_H - QR_SIZE) / 2;

const PANEL_X = QR_CARD_X + QR_CARD_W + COL_GAP;
const PANEL_W = innerW - QR_CARD_W - COL_GAP;
const PANEL_Y = innerY;
const PANEL_H = innerH;

const qrSvg = renderQR({
  content: "https://radicalsolution.com/radical-qr",
  size: QR_SIZE,
  roundness: 0.6,
  eyeRoundness: 1.0,
  eyeScale: 0.85,
  gradient: { start: "#3b82f6", end: "#38c8d5", angle: 135 },
  background: "#ffffff",
  errorCorrection: "M",
  gradientId: "custQr",
});

// Swatches row (selected = last one, the blueCyan gradient)
const swatches = [
  { type: "solid", c: "#000000" },
  { type: "solid", c: "#1e3a5f" },
  { type: "solid", c: "#2d5a3d" },
  { type: "solid", c: "#722f37" },
  { type: "grad",  c1: "#667eea", c2: "#764ba2" },
  { type: "grad",  c1: "#3b82f6", c2: "#38c8d5", selected: true },
  { type: "grad",  c1: "#f97316", c2: "#ec4e8d" },
];

function renderSwatches(x, y, size = 54, gap = 14) {
  return swatches.map((s, i) => {
    const cx = x + i * (size + gap) + size / 2;
    const cy = y + size / 2;
    const stroke = s.selected ? `stroke="#1c1c20" stroke-width="3"` : "";
    if (s.type === "solid") {
      return `<circle cx="${cx}" cy="${cy}" r="${size / 2}" fill="${s.c}" ${stroke}/>`;
    }
    const gid = `swg${i}`;
    return `
      <defs><linearGradient id="${gid}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${s.c1}"/><stop offset="1" stop-color="${s.c2}"/></linearGradient></defs>
      <circle cx="${cx}" cy="${cy}" r="${size / 2}" fill="url(#${gid})" ${stroke}/>
    `;
  }).join("");
}

function presetRow(y, label, options, selectedIdx, { pillW = 120, startX = PANEL_X + 180 } = {}) {
  const rowH = 40;
  const gap = 10;
  const pills = options.map((opt, i) => {
    const x = startX + (pillW + gap) * i;
    const selected = i === selectedIdx;
    const bg = selected ? MAC_COLORS.qrGradientStart : "#eeedf4";
    const fg = selected ? "#ffffff" : "#1c1c20";
    return `
      <rect x="${x}" y="${y}" width="${pillW}" height="${rowH}" rx="14" ry="14" fill="${bg}"/>
      <text x="${x + pillW / 2}" y="${y + rowH / 2 + 6}" text-anchor="middle" font-size="16" font-weight="${selected ? "600" : "500"}" fill="${fg}" font-family="${MAC_FONT}">${escapeXML(opt)}</text>
    `;
  }).join("");
  return `
    <text x="${PANEL_X + 24}" y="${y + rowH / 2 + 6}" font-size="16" font-weight="500" fill="#1c1c20" font-family="${MAC_FONT}">${escapeXML(label)}</text>
    ${pills}
  `;
}

// Section titles positions inside the panel
const SEC_Y_STYLE   = PANEL_Y + 40;
const SEC_Y_COLORS  = PANEL_Y + 140;
const SEC_Y_SHAPE   = PANEL_Y + 300;

const inner = `
  ${macHeadline(L.headline)}

  ${macWindowShell({ activeSidebar: "generator" })}

  <!-- Gradient content pane -->
  <path d="M ${CONTENT.x} ${CONTENT.y}
           H ${CONTENT.x + CONTENT.w - WINDOW.radius}
           a ${WINDOW.radius} ${WINDOW.radius} 0 0 1 ${WINDOW.radius} ${WINDOW.radius}
           V ${CONTENT.y + CONTENT.h - WINDOW.radius}
           a ${WINDOW.radius} ${WINDOW.radius} 0 0 1 ${-WINDOW.radius} ${WINDOW.radius}
           H ${CONTENT.x} Z" fill="url(#macScreenG)"/>

  <!-- App header (inside pane) -->
  <text x="${CONTENT.x + 44}" y="${CONTENT.y + 70}" font-size="36" font-weight="600" fill="#ffffff" font-family="${MAC_FONT}">${escapeXML(L.headline[0])}</text>

  <!-- QR card -->
  <g filter="url(#macCardShadow)">
    <rect x="${QR_CARD_X}" y="${QR_CARD_Y}" width="${QR_CARD_W}" height="${QR_CARD_H}" rx="18" ry="18" fill="#ffffff"/>
    <g transform="translate(${QR_X} ${QR_Y})">${qrSvg}</g>
  </g>

  <!-- Customization panel -->
  <g filter="url(#macCardShadow)">
    <rect x="${PANEL_X}" y="${PANEL_Y}" width="${PANEL_W}" height="${PANEL_H}" rx="18" ry="18" fill="#ffffff"/>
  </g>

  <!-- Style section (Solid / Gradient picker) -->
  <g>
    <text x="${PANEL_X + 24}" y="${SEC_Y_STYLE + 18}" font-size="15" font-weight="700" fill="#6a6a72" letter-spacing="1" font-family="${MAC_FONT}">${escapeXML(L.style.toUpperCase())}</text>
    <rect x="${PANEL_X + 24}" y="${SEC_Y_STYLE + 38}" width="260" height="44" rx="10" ry="10" fill="#eeedf4"/>
    <rect x="${PANEL_X + 24 + 130}" y="${SEC_Y_STYLE + 38}" width="130" height="44" rx="10" ry="10" fill="${MAC_COLORS.qrGradientStart}"/>
    <text x="${PANEL_X + 24 + 65}" y="${SEC_Y_STYLE + 38 + 28}" text-anchor="middle" font-size="16" fill="#1c1c20" font-family="${MAC_FONT}">${escapeXML(L.solid)}</text>
    <text x="${PANEL_X + 24 + 195}" y="${SEC_Y_STYLE + 38 + 28}" text-anchor="middle" font-size="16" font-weight="600" fill="#ffffff" font-family="${MAC_FONT}">${escapeXML(L.gradient)}</text>
  </g>

  <!-- Colors section -->
  <g>
    <text x="${PANEL_X + 24}" y="${SEC_Y_COLORS + 18}" font-size="15" font-weight="700" fill="#6a6a72" letter-spacing="1" font-family="${MAC_FONT}">${escapeXML(L.colors.toUpperCase())}</text>
    ${renderSwatches(PANEL_X + 24, SEC_Y_COLORS + 38)}
  </g>

  <!-- Shape section — Modules / Eyes / Eye Size -->
  <g>
    <text x="${PANEL_X + 24}" y="${SEC_Y_SHAPE + 18}" font-size="15" font-weight="700" fill="#6a6a72" letter-spacing="1" font-family="${MAC_FONT}">${escapeXML(L.shape.toUpperCase())}</text>
    ${presetRow(SEC_Y_SHAPE + 48, L.modules, [L.sharp, L.slight, L.rounded, L.circular], 2, { pillW: 110 })}
    ${presetRow(SEC_Y_SHAPE + 100, L.eyes,    [L.sharp, L.slight, L.rounded, L.circular], 3, { pillW: 110 })}
    ${presetRow(SEC_Y_SHAPE + 152, L.eyeSize, [L.compact, L.medium, L.full],              1, { pillW: 110 })}
  </g>

  ${macSubtitle(L.subtitle)}
`;

fs.mkdirSync(OUT, { recursive: true });
const filename = `m03-customization-mac-${LOCALE}.svg`;
fs.writeFileSync(path.join(OUT, filename), macShell(inner));
console.log("wrote", path.relative(process.cwd(), path.join(OUT, filename)));
