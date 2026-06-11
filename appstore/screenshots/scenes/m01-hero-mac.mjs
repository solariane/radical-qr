/**
 * m01-hero-mac.mjs — Mac App Store hero screenshot (2880 × 1800).
 * Matches the iPhone hero visually: same headline + same "radically simple" vibe.
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

// Main content area — paints the gradient app background and the QR card.
// CONTENT.{x,y,w,h} gives the area right of the sidebar.
const PAD_X = 60;
const APP_X = CONTENT.x + PAD_X;
const APP_W = CONTENT.w - PAD_X * 2;

// QR card: centered horizontally in the content area, below the app header.
const QR_SIZE = 560;
const QR_CARD_W = QR_SIZE + 80;
const QR_CARD_H = QR_SIZE + 80;
const QR_CARD_X = CONTENT.x + (CONTENT.w - QR_CARD_W) / 2;
const QR_CARD_Y = CONTENT.y + 320;

const QR_X = QR_CARD_X + 40;
const QR_Y = QR_CARD_Y + 40;

const qrSvg = renderQR({
  content: "https://radicalsolution.com/radical-qr",
  size: QR_SIZE,
  roundness: 0.35,
  eyeStyle: "leaf",
  eyeScale: 0.88,
  gradient: { start: MAC_COLORS.qrGradientStart, end: MAC_COLORS.qrGradientEnd, angle: 135 },
  background: "#ffffff",
  errorCorrection: "M",
  gradientId: "macQrG",
});

// Fake input chip above the QR
const INPUT_X = APP_X + 40;
const INPUT_Y = CONTENT.y + 180;
const INPUT_W = APP_W - 80;
const INPUT_H = 100;

// Export CTA under the QR
const CTA_W = 280;
const CTA_H = 76;
const CTA_X = CONTENT.x + (CONTENT.w - CTA_W) / 2;
const CTA_Y = QR_CARD_Y + QR_CARD_H + 60;

const inner = `
  ${macHeadline(L.headline)}

  <!-- Window shell with sidebar -->
  ${macWindowShell({ activeSidebar: "generator" })}

  <!-- Right-side gradient "content area" inside the window (mimics GradientBackground) -->
  <g>
    <!-- clip to the right of the sidebar rounded rect, using a subpath with window radius on right side only -->
    <path d="M ${CONTENT.x} ${CONTENT.y}
             H ${CONTENT.x + CONTENT.w - WINDOW.radius}
             a ${WINDOW.radius} ${WINDOW.radius} 0 0 1 ${WINDOW.radius} ${WINDOW.radius}
             V ${CONTENT.y + CONTENT.h - WINDOW.radius}
             a ${WINDOW.radius} ${WINDOW.radius} 0 0 1 ${-WINDOW.radius} ${WINDOW.radius}
             H ${CONTENT.x} Z" fill="url(#macScreenG)"/>
  </g>

  <!-- App header (inside the right pane) -->
  <g fill="#ffffff" font-family="${MAC_FONT}">
    <text x="${CONTENT.x + 44}" y="${CONTENT.y + 74}" font-size="38" font-weight="600">${escapeXML(L.appTitle)}</text>
    <text x="${CONTENT.x + 44}" y="${CONTENT.y + 112}" font-size="20" opacity="0.8">${escapeXML(L.appSubtitle)}</text>
  </g>

  <!-- Input chip -->
  <g>
    <rect x="${INPUT_X}" y="${INPUT_Y}" width="${INPUT_W}" height="${INPUT_H}" rx="18" ry="18" fill="#ffffff"/>
    <text x="${INPUT_X + 28}" y="${INPUT_Y + 42}" font-size="18" font-weight="600" fill="#888" letter-spacing="1" font-family="${MAC_FONT}">URL</text>
    <text x="${INPUT_X + 28}" y="${INPUT_Y + 78}" font-size="24" fill="#333" font-family="${MAC_FONT}">radicalsolution.com/radical-qr</text>
    <circle cx="${INPUT_X + INPUT_W - 40}" cy="${INPUT_Y + INPUT_H / 2}" r="18" fill="#eee"/>
    <text x="${INPUT_X + INPUT_W - 40}" y="${INPUT_Y + INPUT_H / 2 + 8}" text-anchor="middle" font-size="22" fill="#888" font-family="${MAC_FONT}">✕</text>
  </g>

  <!-- QR card -->
  <g filter="url(#macCardShadow)">
    <rect x="${QR_CARD_X}" y="${QR_CARD_Y}" width="${QR_CARD_W}" height="${QR_CARD_H}" rx="22" ry="22" fill="#ffffff"/>
    <g transform="translate(${QR_X} ${QR_Y})">${qrSvg}</g>
  </g>

  <!-- Export CTA -->
  <g>
    <rect x="${CTA_X}" y="${CTA_Y}" width="${CTA_W}" height="${CTA_H}" rx="18" ry="18" fill="url(#macCtaG)"/>
    <text x="${CTA_X + CTA_W / 2}" y="${CTA_Y + CTA_H / 2 + 10}" text-anchor="middle" font-size="26" font-weight="600" fill="#ffffff" font-family="${MAC_FONT}">${escapeXML(L.exportCTA)}</text>
  </g>

  ${macSubtitle(L.subtitle)}
`;

fs.mkdirSync(OUT, { recursive: true });
const filename = `m01-hero-mac-${LOCALE}.svg`;
fs.writeFileSync(path.join(OUT, filename), macShell(inner));
console.log("wrote", path.relative(process.cwd(), path.join(OUT, filename)));
