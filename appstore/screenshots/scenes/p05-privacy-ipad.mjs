/**
 * p05-privacy-ipad.mjs — privacy statement: big lock + 3 promise cards.
 * Uses a full-canvas layout (no device mockup — it's a brand statement).
 */

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  IPAD_CANVAS, IPAD_COLORS, IPAD_FONT,
  ipadSvgShell, ipadHeadline, ipadSubtitle, escapeXML,
} from "../lib/ipad-frame.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.resolve(__dirname, "../out");
const LOCALE = process.argv[2] || "en-US";

const COPY = {
  "en-US": {
    headline: ["Zero tracking.", "Zero servers."],
    subtitle: "Your content never leaves your device.",
    statement: "100% local. 100% private.",
    promises: [
      { icon: "eye", tint: "#34d399", title: "No analytics", body: "No SDKs, no telemetry." },
      { icon: "disk", tint: "#60a5fa", title: "No storage", body: "Ephemeral by default." },
      { icon: "cloud", tint: "#f472b6", title: "Private iCloud", body: "Your container, not ours." },
    ],
  },
  "fr-FR": {
    headline: ["Zéro pistage.", "Zéro serveur."],
    subtitle: "Votre contenu ne quitte jamais votre appareil.",
    statement: "100% local. 100% privé.",
    promises: [
      { icon: "eye", tint: "#34d399", title: "Aucune analytique", body: "Ni SDK, ni télémétrie." },
      { icon: "disk", tint: "#60a5fa", title: "Aucun stockage", body: "Éphémère par défaut." },
      { icon: "cloud", tint: "#f472b6", title: "iCloud privé", body: "Votre conteneur, pas le nôtre." },
    ],
  },
};
const L = COPY[LOCALE] ?? COPY["en-US"];

// Lock icon centered horizontally
const LOCK_CX = IPAD_CANVAS.w / 2;
const LOCK_CY = 800;
const LOCK_R = 160;

// 3 promise cards stacked vertically (portrait → vertical fits better)
const CARD_X = 220;
const CARD_W = IPAD_CANVAS.w - 440;
const CARD_H = 240;
const CARD_GAP = 36;
const CARDS_Y0 = LOCK_CY + LOCK_R + 200;

function iconPath(kind, cx, cy, size, color) {
  const half = size / 2;
  const stroke = `stroke="${color}" stroke-width="7" stroke-linecap="round" stroke-linejoin="round" fill="none"`;
  switch (kind) {
    case "eye":
      return `
        <path d="M ${cx - half} ${cy} Q ${cx} ${cy - half * 0.8} ${cx + half} ${cy} Q ${cx} ${cy + half * 0.8} ${cx - half} ${cy} Z" ${stroke}/>
        <circle cx="${cx}" cy="${cy}" r="${half * 0.35}" ${stroke}/>
        <line x1="${cx - half - 10}" y1="${cy - half + 6}" x2="${cx + half + 10}" y2="${cy + half - 6}" stroke="${color}" stroke-width="8" stroke-linecap="round"/>
      `;
    case "disk":
      return `
        <rect x="${cx - half}" y="${cy - half * 0.7}" width="${size}" height="${size * 0.7}" rx="${half * 0.18}" ry="${half * 0.18}" ${stroke}/>
        <circle cx="${cx}" cy="${cy}" r="${half * 0.32}" ${stroke}/>
        <line x1="${cx - half - 10}" y1="${cy - half + 6}" x2="${cx + half + 10}" y2="${cy + half - 6}" stroke="${color}" stroke-width="8" stroke-linecap="round"/>
      `;
    case "cloud":
      return `
        <path d="M ${cx - half * 0.9} ${cy + half * 0.25} Q ${cx - half * 1.05} ${cy - half * 0.15} ${cx - half * 0.5} ${cy - half * 0.3} Q ${cx - half * 0.3} ${cy - half * 0.75} ${cx + half * 0.1} ${cy - half * 0.55} Q ${cx + half * 0.6} ${cy - half * 0.75} ${cx + half * 0.85} ${cy - half * 0.25} Q ${cx + half * 1.05} ${cy + half * 0.25} ${cx + half * 0.6} ${cy + half * 0.35} L ${cx - half * 0.7} ${cy + half * 0.35} Z" ${stroke}/>
        <rect x="${cx - half * 0.2}" y="${cy - half * 0.1}" width="${half * 0.4}" height="${half * 0.35}" rx="4" ry="4" fill="${color}"/>
      `;
  }
  return "";
}

function promiseCard(idx, promise) {
  const y = CARDS_Y0 + idx * (CARD_H + CARD_GAP);
  const ICON_CX = CARD_X + 100;
  const ICON_CY = y + CARD_H / 2;
  return `
    <rect x="${CARD_X}" y="${y}" width="${CARD_W}" height="${CARD_H}" rx="28" ry="28" fill="#ffffff" opacity="0.2"/>
    <circle cx="${ICON_CX}" cy="${ICON_CY}" r="64" fill="#ffffff"/>
    ${iconPath(promise.icon, ICON_CX, ICON_CY, 68, promise.tint)}
    <text x="${CARD_X + 220}" y="${y + 100}" font-size="40" font-weight="700" fill="#ffffff" font-family="${IPAD_FONT}">${escapeXML(promise.title)}</text>
    <text x="${CARD_X + 220}" y="${y + 158}" font-size="28" fill="#ffffff" opacity="0.85" font-family="${IPAD_FONT}">${escapeXML(promise.body)}</text>
  `;
}

const inner = `
  ${ipadHeadline(L.headline)}

  <!-- Big lock icon -->
  <g>
    <circle cx="${LOCK_CX}" cy="${LOCK_CY}" r="${LOCK_R}" fill="#ffffff" opacity="0.2"/>
    <circle cx="${LOCK_CX}" cy="${LOCK_CY}" r="${LOCK_R - 20}" fill="#ffffff"/>
    <path d="M ${LOCK_CX - 50} ${LOCK_CY - 20}
             V ${LOCK_CY - 58}
             a 50 50 0 0 1 100 0
             V ${LOCK_CY - 20}"
          stroke="${IPAD_COLORS.qrGradientStart}" stroke-width="18" fill="none" stroke-linecap="round"/>
    <rect x="${LOCK_CX - 70}" y="${LOCK_CY - 16}" width="140" height="100" rx="20" ry="20" fill="${IPAD_COLORS.qrGradientStart}"/>
    <circle cx="${LOCK_CX}" cy="${LOCK_CY + 24}" r="10" fill="#ffffff"/>
    <rect x="${LOCK_CX - 5}" y="${LOCK_CY + 24}" width="10" height="28" fill="#ffffff"/>
  </g>

  <!-- Statement -->
  <text x="${IPAD_CANVAS.w / 2}" y="${LOCK_CY + LOCK_R + 140}" text-anchor="middle" font-size="60" font-weight="700" fill="#ffffff" font-family="${IPAD_FONT}">${escapeXML(L.statement)}</text>

  <!-- Promise cards stacked -->
  ${L.promises.map((p, i) => promiseCard(i, p)).join("")}

  ${ipadSubtitle(L.subtitle, { y: CARDS_Y0 + 3 * (CARD_H + CARD_GAP) + 120 })}
`;

fs.mkdirSync(OUT, { recursive: true });
const filename = `p05-privacy-ipad-${LOCALE}.svg`;
fs.writeFileSync(path.join(OUT, filename), ipadSvgShell(inner));
console.log("wrote", path.relative(process.cwd(), path.join(OUT, filename)));
