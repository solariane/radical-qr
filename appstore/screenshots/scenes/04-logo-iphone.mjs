/**
 * 04-logo-iphone.mjs — "add your brand" (Pro feature).
 * Shows a QR with a centered logo + automatic quiet zone.
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
    headline: ["Add your", "brand."],
    subtitle: "Embed any logo — automatic quiet zone.",
    badgePro: "PRO",
    labelLogo: "Logo",
    removeLabel: "Remove",
  },
  "fr-FR": {
    headline: ["Votre", "marque."],
    subtitle: "Intégrez votre logo — zone de sécurité auto.",
    badgePro: "PRO",
    labelLogo: "Logo",
    removeLabel: "Supprimer",
  },
};
const L = COPY[LOCALE] ?? COPY["en-US"];

// --- Layout ----------------------------------------------------------------
const QR_SIZE = 560;
const QR_X = SCREEN.x + (SCREEN.w - QR_SIZE) / 2;
const QR_Y = SCREEN.y + 320;

// We render the QR with high error-correction so the center can be "cut out".
// The logo placement is just a white circle + a stylized monogram.
const qr = renderQR({
  content: "https://radicalsolution.com/radical-qr",
  size: QR_SIZE,
  roundness: 0.35,
  eyeRoundness: 1.0,
  eyeScale: 0.88,
  gradient: { start: COLORS.qrGradientStart, end: COLORS.qrGradientEnd, angle: 135 },
  background: "#ffffff",
  errorCorrection: "H",
  gradientId: "qrG4",
});

// Logo placement (inside the QR)
const LOGO_SIZE = QR_SIZE * 0.26;
const LOGO_CX = QR_X + QR_SIZE / 2;
const LOGO_CY = QR_Y + QR_SIZE / 2;

// Logo section label under the QR
const LOGO_ROW_Y = QR_Y + QR_SIZE + 80;

// In-phone title: "Logo" + inline PRO badge
const PHONE_TITLE_X = CANVAS.w / 2;
const PHONE_TITLE_Y = SCREEN.y + 180;

const inner = `
  ${phoneFrame()}

  <!-- In-phone title: Logo (PRO) -->
  <g font-family="${FONT}" fill="#ffffff" text-anchor="middle">
    <text x="${PHONE_TITLE_X - 60}" y="${PHONE_TITLE_Y}" font-size="46" font-weight="600" text-anchor="end">${escapeXML(L.labelLogo)}</text>
    <rect x="${PHONE_TITLE_X - 40}" y="${PHONE_TITLE_Y - 42}" width="100" height="50" rx="25" ry="25" fill="#ffb800"/>
    <text x="${PHONE_TITLE_X + 10}" y="${PHONE_TITLE_Y - 8}" font-size="26" font-weight="700" fill="#1a1a2a" text-anchor="middle">${escapeXML(L.badgePro)}</text>
  </g>

  <!-- QR card with logo cutout -->
  <g filter="url(#cardShadow)">
    <rect x="${QR_X - 28}" y="${QR_Y - 28}" width="${QR_SIZE + 56}" height="${QR_SIZE + 56}" rx="24" ry="24" fill="#ffffff"/>
    <g transform="translate(${QR_X} ${QR_Y})">${qr}</g>
    <!-- White "safe zone" for the logo -->
    <rect x="${LOGO_CX - LOGO_SIZE * 0.7}" y="${LOGO_CY - LOGO_SIZE * 0.7}" width="${LOGO_SIZE * 1.4}" height="${LOGO_SIZE * 1.4}" rx="22" ry="22" fill="#ffffff"/>
    <!-- Placeholder logo: a stylized "R" in the brand gradient -->
    <circle cx="${LOGO_CX}" cy="${LOGO_CY}" r="${LOGO_SIZE / 2}" fill="url(#ctaG)"/>
    <text x="${LOGO_CX}" y="${LOGO_CY + LOGO_SIZE * 0.24}" text-anchor="middle" font-size="${LOGO_SIZE * 0.75}" font-weight="700" fill="#ffffff" font-family="${FONT}">R</text>
  </g>

  <!-- Simplified logo card under the QR: preview + filename on one line -->
  <g>
    <rect x="${SCREEN.x + 46}" y="${LOGO_ROW_Y}" width="${SCREEN.w - 92}" height="110" rx="22" ry="22" fill="#ffffff" opacity="0.18"/>
    <circle cx="${SCREEN.x + 46 + 55}" cy="${LOGO_ROW_Y + 55}" r="32" fill="url(#ctaG)"/>
    <text x="${SCREEN.x + 46 + 55}" y="${LOGO_ROW_Y + 67}" text-anchor="middle" font-size="30" font-weight="700" fill="#ffffff" font-family="${FONT}">R</text>
    <text x="${SCREEN.x + 46 + 110}" y="${LOGO_ROW_Y + 66}" font-size="26" font-weight="500" fill="#ffffff" font-family="${FONT}">logo-radical.svg</text>
  </g>

  ${headlineBlock(L.headline)}
  ${subtitleBlock(L.subtitle)}
`;

fs.mkdirSync(OUT, { recursive: true });
const filename = `04-logo-iphone-6.9-${LOCALE}.svg`;
fs.writeFileSync(path.join(OUT, filename), svgShell(inner));
console.log("wrote", path.relative(process.cwd(), path.join(OUT, filename)));
