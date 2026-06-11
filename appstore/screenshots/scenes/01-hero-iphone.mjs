/**
 * 01-hero-iphone.mjs — App Store hero screenshot for iPhone 6.9" (1290 × 2796).
 *
 * Layout (top to bottom):
 *   ┌──────────────────────┐
 *   │ gradient bg          │
 *   │                      │
 *   │  "QR codes."         │  headline (white, bold, 2 lines)
 *   │  "Radically simple." │
 *   │                      │
 *   │  ┌──────────────┐    │
 *   │  │              │    │  phone mockup — a simulated screen
 *   │  │   app view   │    │  with the generator + a gradient QR
 *   │  │   with QR    │    │
 *   │  │              │    │
 *   │  └──────────────┘    │
 *   │                      │
 *   │ Auto-detect.         │  subtitle
 *   │ Private. Elegant.    │
 *   └──────────────────────┘
 */

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { renderQR } from "../lib/qr-svg.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.resolve(__dirname, "../out");
const LOCALE = process.argv[2] || "en-US";

const COPY = {
  "en-US": {
    headline: ["QR codes.", "Radically simple."],
    subtitle: "Auto-detect. Private. Elegant.",
    chips: ["No tracking", "No subscription", "SVG & PDF"],
  },
  "fr-FR": {
    headline: ["QR codes.", "Simplement radical."],
    subtitle: "Auto-détectés. Privé. Élégant.",
    chips: ["Sans tracking", "Sans abonnement", "SVG & PDF"],
  },
};
const L = COPY[LOCALE] ?? COPY["en-US"];

// Value chips centered on a row. `cy` = vertical center.
function valueChips(chips, cx, cy) {
  const fs = 38, padX = 34, gap = 26, h = 78;
  const widths = chips.map(t => t.length * fs * 0.56 + padX * 2);
  const total = widths.reduce((a, b) => a + b, 0) + gap * (chips.length - 1);
  let x = cx - total / 2;
  return chips.map((t, i) => {
    const w = widths[i];
    const g = `<g>
      <rect x="${x}" y="${cy - h / 2}" width="${w}" height="${h}" rx="${h / 2}" fill="#ffffff" opacity="0.18"/>
      <text x="${x + w / 2}" y="${cy + fs * 0.36}" text-anchor="middle" font-size="${fs}" font-weight="600" fill="#ffffff" font-family="-apple-system, 'SF Pro Display', sans-serif">${escapeXML(t)}</text>
    </g>`;
    x += w + gap;
    return g;
  }).join("");
}

// ---- Canvas ---------------------------------------------------------------
const W = 1290;
const H = 2796;

// ---- Colors ---------------------------------------------------------------
const BG_START = "#667eea";
const BG_END = "#764ba2";
const PHONE_BEZEL = "#0f0f18";     // near-black with a hint of indigo
const SCREEN_BG_START = "#7b8fef";  // slightly lighter variant of BG for the screen
const SCREEN_BG_END = "#8a5fb8";
const QR_GRADIENT = { start: "#4D33D9", end: "#8C3BBF", angle: 135 };

// ---- Phone mockup ---------------------------------------------------------
// Phone is centered horizontally. Keep ~60% of canvas height.
const PHONE_W = 820;
const PHONE_H = 1680;
const PHONE_X = (W - PHONE_W) / 2;
const PHONE_Y = 700;                // After headline
const PHONE_BEZEL_W = 18;
const PHONE_RADIUS = 110;

const SCREEN_X = PHONE_X + PHONE_BEZEL_W;
const SCREEN_Y = PHONE_Y + PHONE_BEZEL_W;
const SCREEN_W = PHONE_W - PHONE_BEZEL_W * 2;
const SCREEN_H = PHONE_H - PHONE_BEZEL_W * 2;
const SCREEN_RADIUS = PHONE_RADIUS - PHONE_BEZEL_W;

// ---- QR (placed inside the screen) ---------------------------------------
const QR_SIZE = 560;
const QR_X = SCREEN_X + (SCREEN_W - QR_SIZE) / 2;
const QR_Y = SCREEN_Y + 420;  // below a simulated app header

const qrSvg = renderQR({
  content: "https://radicalsolution.com/radical-qr",
  size: QR_SIZE,
  roundness: 0.35,
  eyeStyle: "leaf",
  eyeScale: 0.88,
  gradient: QR_GRADIENT,
  background: "#ffffff",
  errorCorrection: "M",
  gradientId: "qrG",
});

// ---- SVG ------------------------------------------------------------------
// Use text-anchor=middle so labels auto-center.
const svg = `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}">
  <defs>
    <linearGradient id="bgG" x1="0" y1="0" x2="${W}" y2="${H}" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="${BG_START}"/>
      <stop offset="1" stop-color="${BG_END}"/>
    </linearGradient>
    <linearGradient id="screenG" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="${SCREEN_BG_START}"/>
      <stop offset="1" stop-color="${SCREEN_BG_END}"/>
    </linearGradient>
    <filter id="softShadow" x="-20%" y="-20%" width="140%" height="140%">
      <feGaussianBlur in="SourceAlpha" stdDeviation="20"/>
      <feOffset dx="0" dy="16" result="o"/>
      <feComponentTransfer><feFuncA type="linear" slope="0.4"/></feComponentTransfer>
      <feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
    <filter id="qrShadow" x="-10%" y="-10%" width="120%" height="120%">
      <feGaussianBlur in="SourceAlpha" stdDeviation="10"/>
      <feOffset dx="0" dy="10" result="o"/>
      <feComponentTransfer><feFuncA type="linear" slope="0.25"/></feComponentTransfer>
      <feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
  </defs>

  <!-- Canvas background -->
  <rect x="0" y="0" width="${W}" height="${H}" fill="url(#bgG)"/>

  <!-- Headline -->
  <g text-anchor="middle" fill="#ffffff" font-family="-apple-system, 'SF Pro Display', 'Helvetica Neue', Helvetica, Arial, sans-serif">
    <text x="${W / 2}" y="280" font-size="140" font-weight="700" letter-spacing="-3">${escapeXML(L.headline[0])}</text>
    <text x="${W / 2}" y="460" font-size="140" font-weight="700" letter-spacing="-3" opacity="0.92">${escapeXML(L.headline[1])}</text>
  </g>

  <!-- Value chips -->
  ${valueChips(L.chips, W / 2, 600)}

  <!-- Phone bezel -->
  <g filter="url(#softShadow)">
    <rect x="${PHONE_X}" y="${PHONE_Y}" width="${PHONE_W}" height="${PHONE_H}" rx="${PHONE_RADIUS}" ry="${PHONE_RADIUS}" fill="${PHONE_BEZEL}"/>
    <rect x="${SCREEN_X}" y="${SCREEN_Y}" width="${SCREEN_W}" height="${SCREEN_H}" rx="${SCREEN_RADIUS}" ry="${SCREEN_RADIUS}" fill="url(#screenG)"/>
  </g>

  <!-- Dynamic island (pure decoration — hints at a real iPhone) -->
  <rect x="${W / 2 - 90}" y="${SCREEN_Y + 32}" width="180" height="42" rx="21" ry="21" fill="#0a0a12"/>

  <!-- Simulated app content inside the screen -->
  <g text-anchor="middle" font-family="-apple-system, 'SF Pro Display', 'Helvetica Neue', Helvetica, Arial, sans-serif" fill="#ffffff">
    <text x="${W / 2}" y="${SCREEN_Y + 170}" font-size="46" font-weight="600">QR Code Generator</text>
    <text x="${W / 2}" y="${SCREEN_Y + 218}" font-size="22" font-weight="400" opacity="0.75">${LOCALE === "fr-FR" ? "Pas de suivi. Pas de stockage." : "No tracking. No storage."}</text>
  </g>

  <!-- Input chip (simulates the summary card) -->
  <g>
    <rect x="${SCREEN_X + 46}" y="${SCREEN_Y + 260}" width="${SCREEN_W - 92}" height="110" rx="22" ry="22" fill="#ffffff" opacity="0.97"/>
    <text x="${SCREEN_X + 72}" y="${SCREEN_Y + 302}" font-size="24" font-weight="600" fill="#333" font-family="-apple-system, 'SF Pro Display', sans-serif">${LOCALE === "fr-FR" ? "🔗 URL" : "🔗 URL"}</text>
    <text x="${SCREEN_X + 72}" y="${SCREEN_Y + 344}" font-size="22" fill="#666" font-family="-apple-system, 'SF Pro Display', sans-serif">radicalsolution.com/radical-qr</text>
  </g>

  <!-- QR preview card -->
  <g filter="url(#qrShadow)">
    <rect x="${QR_X - 28}" y="${QR_Y - 28}" width="${QR_SIZE + 56}" height="${QR_SIZE + 56}" rx="26" ry="26" fill="#ffffff"/>
    <g transform="translate(${QR_X} ${QR_Y})">${qrSvg}</g>
  </g>

  <!-- Bottom simulated action buttons -->
  <g>
    <rect x="${SCREEN_X + 110}" y="${QR_Y + QR_SIZE + 80}" width="${SCREEN_W - 220}" height="84" rx="18" ry="18"
          fill="url(#qrG2)"/>
    <linearGradient id="qrG2" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="${QR_GRADIENT.start}"/>
      <stop offset="1" stop-color="${QR_GRADIENT.end}"/>
    </linearGradient>
    <text x="${W / 2}" y="${QR_Y + QR_SIZE + 134}" text-anchor="middle" font-size="28" font-weight="600" fill="#ffffff"
          font-family="-apple-system, 'SF Pro Display', sans-serif">${LOCALE === "fr-FR" ? "Exporter" : "Export"}</text>
  </g>

  <!-- Subtitle under the phone -->
  <g text-anchor="middle" font-family="-apple-system, 'SF Pro Display', sans-serif" fill="#ffffff">
    <text x="${W / 2}" y="${PHONE_Y + PHONE_H + 160}" font-size="56" font-weight="500" opacity="0.95">${escapeXML(L.subtitle)}</text>
  </g>
</svg>
`;

// ---- Output ---------------------------------------------------------------
const filename = `01-hero-iphone-6.9-${LOCALE}.svg`;
const outPath = path.join(OUT, filename);
fs.mkdirSync(OUT, { recursive: true });
fs.writeFileSync(outPath, svg);
console.log("wrote", path.relative(process.cwd(), outPath));

function escapeXML(s) {
  return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}
