/**
 * p01-hero-ipad.mjs — iPad Pro 13" portrait hero (2064 × 2752).
 * Uses the NavigationSplitView layout (sidebar + gradient content pane).
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
    headline: ["QR codes.", "Radically simple."],
    subtitle: "Auto-detect. Private. Elegant.",
    appTitle: "QR Code Generator",
    appSubtitle: "No tracking. No storage. Just ephemeral QR codes.",
    exportCTA: "Export",
  },
  "fr-FR": {
    headline: ["QR codes.", "Simplement radical."],
    subtitle: "Auto-détectés. Privé. Élégant.",
    appTitle: "Générateur de QR Code",
    appSubtitle: "Pas de suivi. Pas de stockage. Juste des QR éphémères.",
    exportCTA: "Exporter",
  },
};
const L = COPY[LOCALE] ?? COPY["en-US"];

// --- Layout inside the content pane (right of sidebar) -------------------
const PAD_X = 48;
const APP_X = IPAD_CONTENT.x + PAD_X;
const APP_W = IPAD_CONTENT.w - PAD_X * 2;

const INPUT_X = APP_X;
const INPUT_Y = IPAD_CONTENT.y + 180;
const INPUT_W = APP_W;
const INPUT_H = 110;

const QR_SIZE = 620;
const QR_CARD_W = QR_SIZE + 80;
const QR_CARD_H = QR_SIZE + 80;
const QR_CARD_X = IPAD_CONTENT.x + (IPAD_CONTENT.w - QR_CARD_W) / 2;
const QR_CARD_Y = INPUT_Y + INPUT_H + 60;

const QR_X = QR_CARD_X + 40;
const QR_Y = QR_CARD_Y + 40;

const qrSvg = renderQR({
  content: "https://radicalsolution.com/radical-qr",
  size: QR_SIZE,
  roundness: 0.35,
  eyeRoundness: 1.0,
  eyeScale: 0.88,
  gradient: { start: IPAD_COLORS.qrGradientStart, end: IPAD_COLORS.qrGradientEnd, angle: 135 },
  background: "#ffffff",
  errorCorrection: "M",
  gradientId: "ipadHeroQr",
});

// Export CTA under the QR card
const CTA_W = 320;
const CTA_H = 84;
const CTA_X = IPAD_CONTENT.x + (IPAD_CONTENT.w - CTA_W) / 2;
const CTA_Y = QR_CARD_Y + QR_CARD_H + 50;

const inner = `
  ${ipadHeadline(L.headline)}

  ${ipadShell({ activeSidebar: "generator" })}
  ${ipadContentBackground()}

  <!-- App header inside the content pane -->
  <g fill="#ffffff" font-family="${IPAD_FONT}">
    <text x="${IPAD_CONTENT.x + 48}" y="${IPAD_CONTENT.y + 80}" font-size="42" font-weight="600">${escapeXML(L.appTitle)}</text>
    <text x="${IPAD_CONTENT.x + 48}" y="${IPAD_CONTENT.y + 118}" font-size="22" opacity="0.8">${escapeXML(L.appSubtitle)}</text>
  </g>

  <!-- Input chip -->
  <g>
    <rect x="${INPUT_X}" y="${INPUT_Y}" width="${INPUT_W}" height="${INPUT_H}" rx="18" ry="18" fill="#ffffff"/>
    <text x="${INPUT_X + 28}" y="${INPUT_Y + 46}" font-size="18" font-weight="600" fill="#888" letter-spacing="1" font-family="${IPAD_FONT}">URL</text>
    <text x="${INPUT_X + 28}" y="${INPUT_Y + 82}" font-size="26" fill="#333" font-family="${IPAD_FONT}">radicalsolution.com/radical-qr</text>
  </g>

  <!-- QR card -->
  <g filter="url(#ipadCardShadow)">
    <rect x="${QR_CARD_X}" y="${QR_CARD_Y}" width="${QR_CARD_W}" height="${QR_CARD_H}" rx="22" ry="22" fill="#ffffff"/>
    <g transform="translate(${QR_X} ${QR_Y})">${qrSvg}</g>
  </g>

  <!-- Export CTA -->
  <g>
    <rect x="${CTA_X}" y="${CTA_Y}" width="${CTA_W}" height="${CTA_H}" rx="20" ry="20" fill="url(#ipadCtaG)"/>
    <text x="${CTA_X + CTA_W / 2}" y="${CTA_Y + CTA_H / 2 + 12}" text-anchor="middle" font-size="30" font-weight="600" fill="#ffffff" font-family="${IPAD_FONT}">${escapeXML(L.exportCTA)}</text>
  </g>

  ${ipadSubtitle(L.subtitle)}
`;

fs.mkdirSync(OUT, { recursive: true });
const filename = `p01-hero-ipad-${LOCALE}.svg`;
fs.writeFileSync(path.join(OUT, filename), ipadSvgShell(inner));
console.log("wrote", path.relative(process.cwd(), path.join(OUT, filename)));
