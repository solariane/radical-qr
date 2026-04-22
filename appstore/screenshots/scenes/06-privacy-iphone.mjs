/**
 * 06-privacy-iphone.mjs — "zero tracking. zero servers."
 * Strong statement-focused screen: big lock icon + 3 guarantees.
 */

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  CANVAS, SCREEN, PHONE, COLORS, FONT,
  phoneFrame, headlineBlock, subtitleBlock, svgShell, escapeXML,
} from "../lib/phone-frame.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.resolve(__dirname, "../out");
const LOCALE = process.argv[2] || "en-US";

const COPY = {
  "en-US": {
    headline: ["Zero tracking.", "Zero servers."],
    subtitle: "Your content never leaves your device.",
    promises: [
      { icon: "eye", tint: "#34d399", title: "No analytics", body: "No SDKs, no telemetry." },
      { icon: "disk", tint: "#60a5fa", title: "No storage", body: "Ephemeral by default." },
      { icon: "cloud", tint: "#f472b6", title: "Private iCloud", body: "Your container, not ours." },
    ],
  },
  "fr-FR": {
    headline: ["Zéro pistage.", "Zéro serveur."],
    subtitle: "Votre contenu ne quitte jamais votre appareil.",
    promises: [
      { icon: "eye", tint: "#34d399", title: "Aucune analytique", body: "Ni SDK, ni télémétrie." },
      { icon: "disk", tint: "#60a5fa", title: "Aucun stockage", body: "Éphémère par défaut." },
      { icon: "cloud", tint: "#f472b6", title: "iCloud privé", body: "Votre conteneur, pas le nôtre." },
    ],
  },
};
const L = COPY[LOCALE] ?? COPY["en-US"];

// --- Layout ---------------------------------------------------------------
const LOCK_CY = SCREEN.y + 330;
const LOCK_R = 110;

const PROMISE_Y0 = SCREEN.y + 620;
const PROMISE_H = 190;
const PROMISE_GAP = 32;

/** Small SVG icon set for the privacy promise cards. Stroked, rounded. */
function iconPath(kind, cx, cy, size, color) {
  const half = size / 2;
  const stroke = `stroke="${color}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round" fill="none"`;
  switch (kind) {
    case "eye":
      // Eye with a slash through it (= "no analytics / not watched").
      return `
        <path d="M ${cx - half} ${cy} Q ${cx} ${cy - half * 0.8} ${cx + half} ${cy} Q ${cx} ${cy + half * 0.8} ${cx - half} ${cy} Z" ${stroke}/>
        <circle cx="${cx}" cy="${cy}" r="${half * 0.35}" ${stroke}/>
        <line x1="${cx - half - 8}" y1="${cy - half + 4}" x2="${cx + half + 8}" y2="${cy + half - 4}" stroke="${color}" stroke-width="6" stroke-linecap="round"/>
      `;
    case "disk":
      // Hard disk silhouette with a slash (= "no storage").
      return `
        <rect x="${cx - half}" y="${cy - half * 0.7}" width="${size}" height="${size * 0.7}" rx="${half * 0.18}" ry="${half * 0.18}" ${stroke}/>
        <circle cx="${cx}" cy="${cy}" r="${half * 0.32}" ${stroke}/>
        <line x1="${cx - half - 8}" y1="${cy - half + 4}" x2="${cx + half + 8}" y2="${cy + half - 4}" stroke="${color}" stroke-width="6" stroke-linecap="round"/>
      `;
    case "cloud":
      // Cloud with a lock (= "private iCloud").
      return `
        <path d="M ${cx - half * 0.9} ${cy + half * 0.25} Q ${cx - half * 1.05} ${cy - half * 0.15} ${cx - half * 0.5} ${cy - half * 0.3} Q ${cx - half * 0.3} ${cy - half * 0.75} ${cx + half * 0.1} ${cy - half * 0.55} Q ${cx + half * 0.6} ${cy - half * 0.75} ${cx + half * 0.85} ${cy - half * 0.25} Q ${cx + half * 1.05} ${cy + half * 0.25} ${cx + half * 0.6} ${cy + half * 0.35} L ${cx - half * 0.7} ${cy + half * 0.35} Z" ${stroke}/>
        <rect x="${cx - half * 0.2}" y="${cy - half * 0.1}" width="${half * 0.4}" height="${half * 0.35}" rx="4" ry="4" fill="${color}"/>
      `;
  }
  return "";
}

function promiseCard(idx, promise) {
  const y = PROMISE_Y0 + idx * (PROMISE_H + PROMISE_GAP);
  const x = SCREEN.x + 46;
  const w = SCREEN.w - 92;
  const ICON_CX = x + 80;
  const ICON_CY = y + PROMISE_H / 2;
  return `
    <rect x="${x}" y="${y}" width="${w}" height="${PROMISE_H}" rx="26" ry="26" fill="#ffffff" opacity="0.18"/>
    <circle cx="${ICON_CX}" cy="${ICON_CY}" r="50" fill="#ffffff"/>
    ${iconPath(promise.icon, ICON_CX, ICON_CY, 54, promise.tint)}
    <text x="${x + 170}" y="${y + 76}" font-size="32" font-weight="700" fill="#ffffff" font-family="${FONT}">${escapeXML(promise.title)}</text>
    <text x="${x + 170}" y="${y + 120}" font-size="24" fill="#ffffff" opacity="0.85" font-family="${FONT}">${escapeXML(promise.body)}</text>
  `;
}

const inner = `
  ${phoneFrame()}

  <!-- Big lock icon -->
  <g>
    <circle cx="${CANVAS.w / 2}" cy="${LOCK_CY}" r="${LOCK_R}" fill="#ffffff" opacity="0.18"/>
    <circle cx="${CANVAS.w / 2}" cy="${LOCK_CY}" r="${LOCK_R - 16}" fill="#ffffff"/>
    <!-- Lock shackle (arch) -->
    <path d="M ${CANVAS.w / 2 - 30} ${LOCK_CY - 10}
             V ${LOCK_CY - 36}
             a 30 30 0 0 1 60 0
             V ${LOCK_CY - 10}"
          stroke="#4D33D9" stroke-width="12" fill="none" stroke-linecap="round"/>
    <!-- Lock body -->
    <rect x="${CANVAS.w / 2 - 42}" y="${LOCK_CY - 8}" width="84" height="64" rx="14" ry="14" fill="#4D33D9"/>
    <!-- Keyhole -->
    <circle cx="${CANVAS.w / 2}" cy="${LOCK_CY + 18}" r="6" fill="#ffffff"/>
    <rect x="${CANVAS.w / 2 - 3}" y="${LOCK_CY + 18}" width="6" height="16" fill="#ffffff"/>
  </g>

  <!-- Statement right under the lock -->
  <g text-anchor="middle" font-family="${FONT}" fill="#ffffff">
    <text x="${CANVAS.w / 2}" y="${SCREEN.y + 500}" font-size="38" font-weight="700">${LOCALE === "fr-FR" ? "100% local. 100% privé." : "100% local. 100% private."}</text>
  </g>

  <!-- Promise cards -->
  ${L.promises.map((p, i) => promiseCard(i, p)).join("")}

  ${headlineBlock(L.headline)}
  ${subtitleBlock(L.subtitle)}
`;

fs.mkdirSync(OUT, { recursive: true });
const filename = `06-privacy-iphone-6.9-${LOCALE}.svg`;
fs.writeFileSync(path.join(OUT, filename), svgShell(inner));
console.log("wrote", path.relative(process.cwd(), path.join(OUT, filename)));
