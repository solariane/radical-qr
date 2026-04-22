/**
 * 05-export-iphone.mjs — "print, share, scale".
 * Showcases the export panel: PNG, JPEG, WebP, PDF, SVG, sizes up to 4096.
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
    headline: ["Print. Share.", "Scale."],
    subtitle: "PNG, JPEG, WebP, PDF, SVG — up to 4096 px.",
    size: "Size",
    format: "Format",
    exportCTA: "Export",
  },
  "fr-FR": {
    headline: ["Imprimez.", "Partagez."],
    subtitle: "PNG, JPEG, WebP, PDF, SVG — jusqu'à 4096 px.",
    size: "Taille",
    format: "Format",
    exportCTA: "Exporter",
  },
};
const L = COPY[LOCALE] ?? COPY["en-US"];

// --- Layout ---------------------------------------------------------------
const QR_SIZE = 380;
const QR_X = SCREEN.x + (SCREEN.w - QR_SIZE) / 2;
const QR_Y = SCREEN.y + 190;

const qr = renderQR({
  content: "https://radicalsolution.com/radical-qr",
  size: QR_SIZE,
  roundness: 0.35,
  eyeRoundness: 1.0,
  eyeScale: 0.88,
  gradient: { start: COLORS.qrGradientStart, end: COLORS.qrGradientEnd, angle: 135 },
  background: "#ffffff",
  errorCorrection: "M",
  gradientId: "qrG5",
});

// Size pills
const sizes = [
  { label: "256", pro: false },
  { label: "512", pro: false },
  { label: "1024", pro: true },
  { label: "2048", pro: true },
  { label: "4096", pro: true, selected: true },
];

// Format pills
const formats = [
  { label: "PNG", pro: false },
  { label: "JPEG", pro: false },
  { label: "WebP", pro: false },
  { label: "PDF", pro: true },
  { label: "SVG", pro: true, selected: true },
];

function pillsRow(y, label, items, { pillW = 120 } = {}) {
  const labelX = SCREEN.x + 46;
  const gap = 14;
  const total = items.length * pillW + gap * (items.length - 1);
  const rowX = labelX + 150;
  const parts = items.map((it, i) => {
    const x = rowX + (pillW + gap) * i;
    const selected = Boolean(it.selected);
    const proFlag = Boolean(it.pro);
    const fill = selected ? "#ffffff" : "#ffffff";
    const opacity = selected ? "0.95" : "0.2";
    const textColor = selected ? "#4D33D9" : "#ffffff";
    const lock = proFlag && !selected ? `<text x="${x + pillW - 16}" y="${y + 34}" text-anchor="end" font-size="14" fill="#ffffff" opacity="0.7" font-family="${FONT}">🔒</text>` : "";
    return `
      <rect x="${x}" y="${y}" width="${pillW}" height="54" rx="16" ry="16" fill="${fill}" opacity="${opacity}"/>
      <text x="${x + pillW / 2}" y="${y + 35}" text-anchor="middle" font-size="22" font-weight="${selected ? "700" : "500"}" fill="${textColor}" font-family="${FONT}">${escapeXML(it.label)}</text>
      ${lock}
    `;
  }).join("");

  return `
    <text x="${labelX}" y="${y + 35}" font-size="24" font-weight="600" fill="#ffffff" opacity="0.85" font-family="${FONT}">${escapeXML(label)}</text>
    ${parts}
  `;
}

// Layout Y positions inside the screen
const SIZE_Y = QR_Y + QR_SIZE + 140;
const FORMAT_Y = SIZE_Y + 100;

// Big CTA at the bottom of the screen
const CTA_Y = FORMAT_Y + 160;
const CTA_H = 100;
const CTA_X = SCREEN.x + 60;
const CTA_W = SCREEN.w - 120;

const inner = `
  ${phoneFrame()}

  <!-- App header -->
  <g text-anchor="middle" font-family="${FONT}" fill="#ffffff">
    <text x="${CANVAS.w / 2}" y="${SCREEN.y + 130}" font-size="42" font-weight="600">${LOCALE === "fr-FR" ? "Exporter" : "Export"}</text>
  </g>

  <!-- QR card (compact) -->
  <g filter="url(#cardShadow)">
    <rect x="${QR_X - 24}" y="${QR_Y - 24}" width="${QR_SIZE + 48}" height="${QR_SIZE + 48}" rx="22" ry="22" fill="#ffffff"/>
    <g transform="translate(${QR_X} ${QR_Y})">${qr}</g>
  </g>

  ${pillsRow(SIZE_Y, L.size, sizes, { pillW: 106 })}
  ${pillsRow(FORMAT_Y, L.format, formats, { pillW: 106 })}

  <!-- Export CTA -->
  <g>
    <rect x="${CTA_X}" y="${CTA_Y}" width="${CTA_W}" height="${CTA_H}" rx="22" ry="22" fill="url(#ctaG)"/>
    <text x="${CTA_X + CTA_W / 2}" y="${CTA_Y + CTA_H / 2 + 12}" text-anchor="middle" font-size="32" font-weight="700" fill="#ffffff" font-family="${FONT}">${escapeXML(L.exportCTA)} SVG · 4096 px</text>
  </g>

  ${headlineBlock(L.headline)}
  ${subtitleBlock(L.subtitle)}
`;

fs.mkdirSync(OUT, { recursive: true });
const filename = `05-export-iphone-6.9-${LOCALE}.svg`;
fs.writeFileSync(path.join(OUT, filename), svgShell(inner));
console.log("wrote", path.relative(process.cwd(), path.join(OUT, filename)));
