/**
 * p04-logo-ipad.mjs — QR with embedded logo + Pro badge.
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
    headline: ["Add your", "brand."],
    subtitle: "Embed any logo — automatic quiet zone.",
    appTitle: "Logo",
    badgePro: "PRO",
    filename: "logo-radical.svg",
  },
  "fr-FR": {
    headline: ["Votre", "marque."],
    subtitle: "Intégrez votre logo — zone de sécurité auto.",
    appTitle: "Logo",
    badgePro: "PRO",
    filename: "logo-radical.svg",
  },
};
const L = COPY[LOCALE] ?? COPY["en-US"];

const PAD_X = 48;
const APP_X = IPAD_CONTENT.x + PAD_X;
const APP_W = IPAD_CONTENT.w - PAD_X * 2;

// QR with logo
const QR_SIZE = 660;
const QR_CARD_W = QR_SIZE + 80;
const QR_CARD_H = QR_SIZE + 80;
const QR_CARD_X = IPAD_CONTENT.x + (IPAD_CONTENT.w - QR_CARD_W) / 2;
const QR_CARD_Y = IPAD_CONTENT.y + 220;

const qrSvg = renderQR({
  content: "https://radicalsolution.com/radical-qr",
  size: QR_SIZE,
  roundness: 0.35,
  eyeRoundness: 1.0,
  eyeScale: 0.88,
  gradient: { start: IPAD_COLORS.qrGradientStart, end: IPAD_COLORS.qrGradientEnd, angle: 135 },
  background: "#ffffff",
  errorCorrection: "H",
  gradientId: "ipadLogoQr",
});

const LOGO_SIZE = QR_SIZE * 0.26;
const LOGO_CX = QR_CARD_X + 40 + QR_SIZE / 2;
const LOGO_CY = QR_CARD_Y + 40 + QR_SIZE / 2;

// Logo file card below
const LOGO_ROW_Y = QR_CARD_Y + QR_CARD_H + 48;
const LOGO_ROW_H = 130;

const inner = `
  ${ipadHeadline(L.headline)}

  ${ipadShell({ activeSidebar: "generator" })}
  ${ipadContentBackground()}

  <!-- App header with PRO badge inline -->
  <g font-family="${IPAD_FONT}" fill="#ffffff">
    <text x="${IPAD_CONTENT.x + 48}" y="${IPAD_CONTENT.y + 100}" font-size="42" font-weight="600">${escapeXML(L.appTitle)}</text>
    <rect x="${IPAD_CONTENT.x + 48 + 110}" y="${IPAD_CONTENT.y + 68}" width="84" height="40" rx="20" ry="20" fill="#ffb800"/>
    <text x="${IPAD_CONTENT.x + 48 + 152}" y="${IPAD_CONTENT.y + 96}" text-anchor="middle" font-size="22" font-weight="700" fill="#1a1a2a">${escapeXML(L.badgePro)}</text>
  </g>

  <!-- QR card with centered logo -->
  <g filter="url(#ipadCardShadow)">
    <rect x="${QR_CARD_X}" y="${QR_CARD_Y}" width="${QR_CARD_W}" height="${QR_CARD_H}" rx="22" ry="22" fill="#ffffff"/>
    <g transform="translate(${QR_CARD_X + 40} ${QR_CARD_Y + 40})">${qrSvg}</g>
    <!-- White quiet zone around the logo -->
    <rect x="${LOGO_CX - LOGO_SIZE * 0.7}" y="${LOGO_CY - LOGO_SIZE * 0.7}" width="${LOGO_SIZE * 1.4}" height="${LOGO_SIZE * 1.4}" rx="24" ry="24" fill="#ffffff"/>
    <!-- Logo: circular "R" in the brand gradient -->
    <circle cx="${LOGO_CX}" cy="${LOGO_CY}" r="${LOGO_SIZE / 2}" fill="url(#ipadCtaG)"/>
    <text x="${LOGO_CX}" y="${LOGO_CY + LOGO_SIZE * 0.26}" text-anchor="middle" font-size="${LOGO_SIZE * 0.78}" font-weight="700" fill="#ffffff" font-family="${IPAD_FONT}">R</text>
  </g>

  <!-- Logo file card -->
  <g>
    <rect x="${APP_X}" y="${LOGO_ROW_Y}" width="${APP_W}" height="${LOGO_ROW_H}" rx="22" ry="22" fill="#ffffff" opacity="0.22"/>
    <circle cx="${APP_X + 66}" cy="${LOGO_ROW_Y + LOGO_ROW_H / 2}" r="38" fill="url(#ipadCtaG)"/>
    <text x="${APP_X + 66}" y="${LOGO_ROW_Y + LOGO_ROW_H / 2 + 14}" text-anchor="middle" font-size="38" font-weight="700" fill="#ffffff" font-family="${IPAD_FONT}">R</text>
    <text x="${APP_X + 130}" y="${LOGO_ROW_Y + LOGO_ROW_H / 2 + 12}" font-size="30" font-weight="500" fill="#ffffff" font-family="${IPAD_FONT}">${escapeXML(L.filename)}</text>
  </g>

  ${ipadSubtitle(L.subtitle)}
`;

fs.mkdirSync(OUT, { recursive: true });
const filename = `p04-logo-ipad-${LOCALE}.svg`;
fs.writeFileSync(path.join(OUT, filename), ipadSvgShell(inner));
console.log("wrote", path.relative(process.cwd(), path.join(OUT, filename)));
