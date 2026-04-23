/**
 * p02-auto-detect-ipad.mjs — Paste a vCard, get the right QR.
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
    headline: ["Paste anything.", "Get the right QR."],
    subtitle: ["URL, email, Wi-Fi, contact, event — autodetected", "it just works."],
    appTitle: "QR Code Generator",
    chipTitle: "Contact",
    chipDetail: "John Doe · john@example.com",
    typeLabel: "Contact card",
    typeHint: "vCard · auto-detected",
  },
  "fr-FR": {
    headline: ["Collez.", "L'app comprend."],
    subtitle: ["URL, email, Wi-Fi, contact, événement — auto-détectés", "ça marche."],
    appTitle: "Générateur de QR Code",
    chipTitle: "Contact",
    chipDetail: "Jean Dupont · jean@exemple.fr",
    typeLabel: "Carte de contact",
    typeHint: "vCard · auto-détectée",
  },
};
const L = COPY[LOCALE] ?? COPY["en-US"];

// Layout
const PAD_X = 48;
const APP_X = IPAD_CONTENT.x + PAD_X;
const APP_W = IPAD_CONTENT.w - PAD_X * 2;

// Summary chip (replaces raw vCard blob)
const CHIP_X = APP_X;
const CHIP_Y = IPAD_CONTENT.y + 180;
const CHIP_W = APP_W;
const CHIP_H = 150;

// Data-type indicator
const TYPE_Y = CHIP_Y + CHIP_H + 34;
const TYPE_H = 110;

// QR card
const QR_SIZE = 560;
const QR_CARD_W = QR_SIZE + 80;
const QR_CARD_H = QR_SIZE + 80;
const QR_CARD_X = IPAD_CONTENT.x + (IPAD_CONTENT.w - QR_CARD_W) / 2;
const QR_CARD_Y = TYPE_Y + TYPE_H + 50;

const qrSvg = renderQR({
  content: "BEGIN:VCARD\nFN:John Doe\nEMAIL:john@example.com\nEND:VCARD",
  size: QR_SIZE,
  roundness: 0.25,
  eyeRoundness: 1.0,
  eyeScale: 0.88,
  gradient: { start: IPAD_COLORS.qrGradientStart, end: IPAD_COLORS.qrGradientEnd, angle: 135 },
  background: "#ffffff",
  errorCorrection: "H",
  gradientId: "ipadAutoQr",
});

const inner = `
  ${ipadHeadline(L.headline)}

  ${ipadShell({ activeSidebar: "generator" })}
  ${ipadContentBackground()}

  <!-- App header -->
  <g fill="#ffffff" font-family="${IPAD_FONT}">
    <text x="${IPAD_CONTENT.x + 48}" y="${IPAD_CONTENT.y + 100}" font-size="42" font-weight="600">${escapeXML(L.appTitle)}</text>
  </g>

  <!-- Summary chip: person + name + email (clean replacement for raw vCard) -->
  <g>
    <rect x="${CHIP_X}" y="${CHIP_Y}" width="${CHIP_W}" height="${CHIP_H}" rx="22" ry="22" fill="#ffffff"/>
    <circle cx="${CHIP_X + 70}" cy="${CHIP_Y + CHIP_H / 2}" r="38" fill="#e8ebff"/>
    <text x="${CHIP_X + 70}" y="${CHIP_Y + CHIP_H / 2 + 14}" text-anchor="middle" font-size="42" fill="${IPAD_COLORS.qrGradientStart}" font-family="${IPAD_FONT}">👤</text>
    <text x="${CHIP_X + 130}" y="${CHIP_Y + 60}" font-size="30" font-weight="600" fill="#222" font-family="${IPAD_FONT}">${escapeXML(L.chipTitle)}</text>
    <text x="${CHIP_X + 130}" y="${CHIP_Y + 104}" font-size="24" fill="#666" font-family="${IPAD_FONT}">${escapeXML(L.chipDetail)}</text>
  </g>

  <!-- Data-type indicator card -->
  <g>
    <rect x="${APP_X}" y="${TYPE_Y}" width="${APP_W}" height="${TYPE_H}" rx="22" ry="22" fill="#ffffff" opacity="0.22"/>
    <circle cx="${APP_X + 60}" cy="${TYPE_Y + TYPE_H / 2}" r="30" fill="#ffffff"/>
    <text x="${APP_X + 60}" y="${TYPE_Y + TYPE_H / 2 + 12}" text-anchor="middle" font-size="30" fill="${IPAD_COLORS.qrGradientStart}" font-family="${IPAD_FONT}">👤</text>
    <text x="${APP_X + 110}" y="${TYPE_Y + 46}" font-size="28" font-weight="700" fill="#ffffff" font-family="${IPAD_FONT}">${escapeXML(L.typeLabel)}</text>
    <text x="${APP_X + 110}" y="${TYPE_Y + 82}" font-size="20" fill="#ffffff" opacity="0.85" font-family="${IPAD_FONT}">${escapeXML(L.typeHint)}</text>
  </g>

  <!-- QR card -->
  <g filter="url(#ipadCardShadow)">
    <rect x="${QR_CARD_X}" y="${QR_CARD_Y}" width="${QR_CARD_W}" height="${QR_CARD_H}" rx="22" ry="22" fill="#ffffff"/>
    <g transform="translate(${QR_CARD_X + 40} ${QR_CARD_Y + 40})">${qrSvg}</g>
  </g>

  ${ipadSubtitle(L.subtitle)}
`;

fs.mkdirSync(OUT, { recursive: true });
const filename = `p02-auto-detect-ipad-${LOCALE}.svg`;
fs.writeFileSync(path.join(OUT, filename), ipadSvgShell(inner));
console.log("wrote", path.relative(process.cwd(), path.join(OUT, filename)));
