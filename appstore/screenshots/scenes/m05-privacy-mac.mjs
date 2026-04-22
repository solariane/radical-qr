/**
 * m05-privacy-mac.mjs — landscape privacy statement scene.
 * Big lock icon + 3 promise cards in a horizontal row.
 */

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  MAC_CANVAS, MAC_COLORS, MAC_FONT,
  macShell, macHeadline, macSubtitle, escapeXML,
} from "../lib/mac-frame.mjs";

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

// Central lock icon
const LOCK_CX = MAC_CANVAS.w / 2;
const LOCK_CY = 620;
const LOCK_R = 130;

// 3 promise cards in a horizontal row
const CARD_W = 680;
const CARD_H = 240;
const CARD_GAP = 80;
const TOTAL_W = CARD_W * 3 + CARD_GAP * 2;
const CARDS_X = (MAC_CANVAS.w - TOTAL_W) / 2;
const CARDS_Y = 1040;

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
  const x = CARDS_X + idx * (CARD_W + CARD_GAP);
  const y = CARDS_Y;
  const ICON_CX = x + 90;
  const ICON_CY = y + CARD_H / 2;
  return `
    <rect x="${x}" y="${y}" width="${CARD_W}" height="${CARD_H}" rx="28" ry="28" fill="#ffffff" opacity="0.2"/>
    <circle cx="${ICON_CX}" cy="${ICON_CY}" r="60" fill="#ffffff"/>
    ${iconPath(promise.icon, ICON_CX, ICON_CY, 64, promise.tint)}
    <text x="${x + 200}" y="${y + 100}" font-size="38" font-weight="700" fill="#ffffff" font-family="${MAC_FONT}">${escapeXML(promise.title)}</text>
    <text x="${x + 200}" y="${y + 158}" font-size="26" fill="#ffffff" opacity="0.85" font-family="${MAC_FONT}">${escapeXML(promise.body)}</text>
  `;
}

const inner = `
  ${macHeadline(L.headline)}

  <!-- Big lock icon -->
  <g>
    <circle cx="${LOCK_CX}" cy="${LOCK_CY}" r="${LOCK_R}" fill="#ffffff" opacity="0.2"/>
    <circle cx="${LOCK_CX}" cy="${LOCK_CY}" r="${LOCK_R - 18}" fill="#ffffff"/>
    <!-- shackle -->
    <path d="M ${LOCK_CX - 40} ${LOCK_CY - 16}
             V ${LOCK_CY - 48}
             a 40 40 0 0 1 80 0
             V ${LOCK_CY - 16}"
          stroke="${MAC_COLORS.qrGradientStart}" stroke-width="15" fill="none" stroke-linecap="round"/>
    <!-- body -->
    <rect x="${LOCK_CX - 55}" y="${LOCK_CY - 12}" width="110" height="82" rx="18" ry="18" fill="${MAC_COLORS.qrGradientStart}"/>
    <circle cx="${LOCK_CX}" cy="${LOCK_CY + 18}" r="8" fill="#ffffff"/>
    <rect x="${LOCK_CX - 4}" y="${LOCK_CY + 18}" width="8" height="22" fill="#ffffff"/>
  </g>

  <!-- Statement below the lock -->
  <text x="${MAC_CANVAS.w / 2}" y="${LOCK_CY + LOCK_R + 110}" text-anchor="middle" font-size="52" font-weight="700" fill="#ffffff" font-family="${MAC_FONT}">${escapeXML(L.statement)}</text>

  <!-- Promise cards row -->
  ${L.promises.map((p, i) => promiseCard(i, p)).join("")}

  ${macSubtitle(L.subtitle, { y: CARDS_Y + CARD_H + 140 })}
`;

fs.mkdirSync(OUT, { recursive: true });
const filename = `m05-privacy-mac-${LOCALE}.svg`;
fs.writeFileSync(path.join(OUT, filename), macShell(inner));
console.log("wrote", path.relative(process.cwd(), path.join(OUT, filename)));
