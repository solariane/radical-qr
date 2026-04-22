/**
 * 03-customization-iphone.mjs — "your style, your codes".
 * Shows the QR with a custom gradient + eye controls visible below.
 */

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { renderQR } from "../lib/qr-svg.mjs";
import {
  CANVAS, SCREEN, PHONE, COLORS, FONT,
  phoneFrame, headlineBlock, subtitleBlock, svgShell, escapeXML,
} from "../lib/phone-frame.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.resolve(__dirname, "../out");
const LOCALE = process.argv[2] || "en-US";

const COPY = {
  "en-US": {
    headline: ["Your style.", "Your codes."],
    subtitle: ["Colors, gradients, rounded eyes —", "independent controls."],
    modules: "Modules", eyes: "Eyes", eyeSize: "Eye Size",
    sharp: "Sharp", slight: "Slight", rounded: "Rounded", circular: "Circular",
    compact: "Compact", medium: "Medium", full: "Full",
  },
  "fr-FR": {
    headline: ["Votre style.", "Vos codes."],
    subtitle: ["Couleurs, dégradés, yeux arrondis —", "réglages indépendants."],
    modules: "Modules", eyes: "Yeux", eyeSize: "Taille yeux",
    sharp: "Net", slight: "Léger", rounded: "Arrondi", circular: "Rond",
    compact: "Compact", medium: "Moyen", full: "Plein",
  },
};
const L = COPY[LOCALE] ?? COPY["en-US"];

// --- Layout ----------------------------------------------------------------
const QR_SIZE = 520;
const QR_X = SCREEN.x + (SCREEN.w - QR_SIZE) / 2;
const QR_Y = SCREEN.y + 180;

const qr = renderQR({
  content: "https://radicalsolution.com/radical-qr",
  size: QR_SIZE,
  roundness: 0.6,
  eyeRoundness: 1.0,
  eyeScale: 0.88,
  gradient: { start: "#3b82f6", end: "#38c8d5", angle: 135 }, // blueCyan preset
  background: "#ffffff",
  errorCorrection: "M",
  gradientId: "qrG3",
});

// Color swatches row
const swatches = [
  ["#1e3a5f", "#1e3a5f", "#1e3a5f"], // navy solid
  ["#2d5a3d", "#2d5a3d", "#2d5a3d"], // forest solid
  ["#3b82f6", "#38c8d5", "blueCyan"], // gradient
  ["#667eea", "#764ba2", "purpleViolet"], // gradient (currently selected)
  ["#f97316", "#ec4e8d", "orangePink"], // gradient
];

const SW_SIZE = 56;
const SW_Y = QR_Y + QR_SIZE + 90;
const SW_GAP = 20;
const SW_TOTAL_W = SW_SIZE * swatches.length + SW_GAP * (swatches.length - 1);
const SW_X = SCREEN.x + (SCREEN.w - SW_TOTAL_W) / 2;

// Preset rows (Modules / Eyes / Eye Size)
const ROW_Y_START = SW_Y + SW_SIZE + 50;
const ROW_H = 70;
function presetRow(y, label, options, selectedIdx) {
  const labelX = SCREEN.x + 46;
  const pillX0 = labelX + 200;
  const pillGap = 10;
  const pillW = (SCREEN.w - 92 - 200 - pillGap * (options.length - 1)) / options.length;

  const pills = options.map((opt, i) => {
    const x = pillX0 + (pillW + pillGap) * i;
    const selected = i === selectedIdx;
    const fill = selected ? "#ffffff" : "#ffffff";
    const opacity = selected ? "0.95" : "0.2";
    const textColor = selected ? "#4D33D9" : "#ffffff";
    return `
      <rect x="${x}" y="${y}" width="${pillW}" height="${ROW_H - 20}" rx="22" ry="22" fill="${fill}" opacity="${opacity}"/>
      <text x="${x + pillW / 2}" y="${y + (ROW_H - 20) / 2 + 9}" text-anchor="middle" font-size="22" font-weight="${selected ? "600" : "500"}" fill="${textColor}" font-family="${FONT}">${escapeXML(opt)}</text>
    `;
  }).join("");

  return `
    <text x="${labelX}" y="${y + (ROW_H - 20) / 2 + 9}" font-size="24" font-weight="500" fill="#ffffff" opacity="0.85" font-family="${FONT}">${escapeXML(label)}</text>
    ${pills}
  `;
}

const inner = `
  ${phoneFrame()}

  <!-- QR card (no redundant in-phone title — the overlay headline does the job) -->
  <g filter="url(#cardShadow)">
    <rect x="${QR_X - 28}" y="${QR_Y - 28}" width="${QR_SIZE + 56}" height="${QR_SIZE + 56}" rx="24" ry="24" fill="#ffffff"/>
    <g transform="translate(${QR_X} ${QR_Y})">${qr}</g>
  </g>

  <!-- Color swatches -->
  <g>
    ${swatches.map((s, i) => {
      const x = SW_X + (SW_SIZE + SW_GAP) * i;
      const isGradient = s[0] !== s[1];
      if (isGradient) {
        const gid = `sw${i}`;
        return `
          <defs><linearGradient id="${gid}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${s[0]}"/><stop offset="1" stop-color="${s[1]}"/></linearGradient></defs>
          <circle cx="${x + SW_SIZE / 2}" cy="${SW_Y + SW_SIZE / 2}" r="${SW_SIZE / 2}" fill="url(#${gid})" stroke="${i === 3 ? "#ffffff" : "transparent"}" stroke-width="3"/>
        `;
      }
      return `<circle cx="${x + SW_SIZE / 2}" cy="${SW_Y + SW_SIZE / 2}" r="${SW_SIZE / 2}" fill="${s[0]}" stroke="${i === 3 ? "#ffffff" : "transparent"}" stroke-width="3"/>`;
    }).join("")}
  </g>

  <!-- Preset rows -->
  ${presetRow(ROW_Y_START, L.modules, [L.sharp, L.slight, L.rounded, L.circular], 2)}
  ${presetRow(ROW_Y_START + ROW_H + 10, L.eyes, [L.sharp, L.slight, L.rounded, L.circular], 3)}
  ${presetRow(ROW_Y_START + (ROW_H + 10) * 2, L.eyeSize, [L.compact, L.medium, L.full], 1)}

  ${headlineBlock(L.headline)}
  ${subtitleBlock(L.subtitle)}
`;

fs.mkdirSync(OUT, { recursive: true });
const filename = `03-customization-iphone-6.9-${LOCALE}.svg`;
fs.writeFileSync(path.join(OUT, filename), svgShell(inner));
console.log("wrote", path.relative(process.cwd(), path.join(OUT, filename)));
