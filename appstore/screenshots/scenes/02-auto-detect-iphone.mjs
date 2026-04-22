/**
 * 02-auto-detect-iphone.mjs — "paste anything, get the right QR".
 * Shows the app recognizing a vCard and replacing the raw blob with a
 * readable summary chip, plus the data-type indicator above the QR preview.
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
    headline: ["Paste anything.", "Get the right QR."],
    subtitle: ["URL, email, Wi-Fi, contact, event — autodetected", "it just works."],
    appTitle: "QR Code Generator",
    appSubtitle: "No tracking. No storage.",
    chipType: "Contact",
    chipDetail: "John Doe · john@example.com",
    typeLabel: "Contact card",
    typeHint: "vCard · auto-detected",
  },
  "fr-FR": {
    headline: ["Collez.", "L'app comprend."],
    subtitle: ["URL, email, Wi-Fi, contact, événement — auto-détectés", "ça marche."],
    appTitle: "Générateur de QR Code",
    appSubtitle: "Pas de suivi. Pas de stockage.",
    chipType: "Contact",
    chipDetail: "Jean Dupont · jean@exemple.fr",
    typeLabel: "Carte de contact",
    typeHint: "vCard · auto-détectée",
  },
};
const L = COPY[LOCALE] ?? COPY["en-US"];

// --- Layout pieces inside the phone screen --------------------------------
const QR_SIZE = 460;
const QR_X = SCREEN.x + (SCREEN.w - QR_SIZE) / 2;
const QR_Y = SCREEN.y + 610;

const qr = renderQR({
  content: "BEGIN:VCARD\nFN:John Doe\nEMAIL:john@example.com\nEND:VCARD",
  size: QR_SIZE,
  roundness: 0.25,
  eyeRoundness: 1.0,
  eyeScale: 0.88,
  gradient: { start: COLORS.qrGradientStart, end: COLORS.qrGradientEnd, angle: 135 },
  background: "#ffffff",
  errorCorrection: "H",
  gradientId: "qrG2",
});

// --- Summary chip (replaces raw vCard) -----------------------------------
const CHIP_X = SCREEN.x + 46;
const CHIP_W = SCREEN.w - 92;
const CHIP_Y = SCREEN.y + 270;
const CHIP_H = 140;

// --- Data-type indicator (above the QR) ----------------------------------
const TYPE_Y = SCREEN.y + 450;

const inner = `
  ${phoneFrame()}

  <!-- App header -->
  <g text-anchor="middle" font-family="${FONT}" fill="#ffffff">
    <text x="${CANVAS.w / 2}" y="${SCREEN.y + 170}" font-size="46" font-weight="600">${escapeXML(L.appTitle)}</text>
    <text x="${CANVAS.w / 2}" y="${SCREEN.y + 218}" font-size="22" opacity="0.75">${escapeXML(L.appSubtitle)}</text>
  </g>

  <!-- Summary chip: person icon + name + email -->
  <g>
    <rect x="${CHIP_X}" y="${CHIP_Y}" width="${CHIP_W}" height="${CHIP_H}" rx="22" ry="22" fill="#ffffff"/>
    <circle cx="${CHIP_X + 50}" cy="${CHIP_Y + CHIP_H / 2}" r="28" fill="#e8ebff"/>
    <text x="${CHIP_X + 50}" y="${CHIP_Y + CHIP_H / 2 + 10}" text-anchor="middle" font-size="30" fill="${COLORS.qrGradientStart}" font-family="${FONT}">👤</text>
    <text x="${CHIP_X + 100}" y="${CHIP_Y + 52}" font-size="26" font-weight="600" fill="#222" font-family="${FONT}">${escapeXML(L.chipType)}</text>
    <text x="${CHIP_X + 100}" y="${CHIP_Y + 90}" font-size="22" fill="#666" font-family="${FONT}">${escapeXML(L.chipDetail)}</text>
    <text x="${CHIP_X + CHIP_W - 40}" y="${CHIP_Y + CHIP_H / 2 + 10}" text-anchor="middle" font-size="30" fill="#bbb" font-family="${FONT}">✕</text>
  </g>

  <!-- Data-type indicator card (bigger — this is the key differentiator) -->
  <g>
    <rect x="${SCREEN.x + 46}" y="${TYPE_Y - 10}" width="${SCREEN.w - 92}" height="108" rx="24" ry="24" fill="#ffffff" opacity="0.22"/>
    <circle cx="${SCREEN.x + 46 + 52}" cy="${TYPE_Y + 44}" r="30" fill="#ffffff"/>
    <text x="${SCREEN.x + 46 + 52}" y="${TYPE_Y + 56}" text-anchor="middle" font-size="32" fill="${COLORS.qrGradientStart}" font-family="${FONT}">👤</text>
    <text x="${SCREEN.x + 46 + 110}" y="${TYPE_Y + 38}" font-size="32" font-weight="700" fill="#ffffff" font-family="${FONT}">${escapeXML(L.typeLabel)}</text>
    <text x="${SCREEN.x + 46 + 110}" y="${TYPE_Y + 72}" font-size="22" fill="#ffffff" opacity="0.85" font-family="${FONT}">${escapeXML(L.typeHint)}</text>
  </g>

  <!-- QR card -->
  <g filter="url(#cardShadow)">
    <rect x="${QR_X - 28}" y="${QR_Y - 28}" width="${QR_SIZE + 56}" height="${QR_SIZE + 56}" rx="24" ry="24" fill="#ffffff"/>
    <g transform="translate(${QR_X} ${QR_Y})">${qr}</g>
  </g>

  ${headlineBlock(L.headline)}
  ${subtitleBlock(L.subtitle)}
`;

fs.mkdirSync(OUT, { recursive: true });
const filename = `02-auto-detect-iphone-6.9-${LOCALE}.svg`;
fs.writeFileSync(path.join(OUT, filename), svgShell(inner));
console.log("wrote", path.relative(process.cwd(), path.join(OUT, filename)));
