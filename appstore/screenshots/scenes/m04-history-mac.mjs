/**
 * m04-history-mac.mjs — History & iCloud sync (Pro feature).
 * Shows the app with the "Recent" horizontal strip visible below the QR.
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
    headline: ["One click.", "Remake any code."],
    subtitle: "Your recent QR codes, synced through iCloud.",
    appTitle: "QR Code Generator",
    recent: "Recent",
    items: [
      { label: "radicalsolution.com", type: "url" },
      { label: "Claire Dubois", type: "vcard" },
      { label: "Wi-Fi: Studio", type: "wifi" },
      { label: "Design review", type: "ical" },
      { label: "contact@radicalsolution.com", type: "email" },
      { label: "+33 6 12 34 56 78", type: "tel" },
    ],
  },
  "fr-FR": {
    headline: ["Un clic.", "Tous vos QR."],
    subtitle: "Vos QR codes récents, synchronisés via iCloud.",
    appTitle: "Générateur de QR Code",
    recent: "Récents",
    items: [
      { label: "radicalsolution.com", type: "url" },
      { label: "Claire Dubois", type: "vcard" },
      { label: "Wi-Fi : Studio", type: "wifi" },
      { label: "Réunion design", type: "ical" },
      { label: "contact@radicalsolution.com", type: "email" },
      { label: "+33 6 12 34 56 78", type: "tel" },
    ],
  },
};
const L = COPY[LOCALE] ?? COPY["en-US"];

// Map type → small color palette for distinct thumbnail previews
const TYPE_COLORS = {
  url:    { start: "#4D33D9", end: "#8C3BBF" },
  vcard:  { start: "#3b82f6", end: "#38c8d5" },
  wifi:   { start: "#0ea5e9", end: "#6366f1" },
  ical:   { start: "#f97316", end: "#ec4e8d" },
  email:  { start: "#10b981", end: "#3b82f6" },
  tel:    { start: "#a855f7", end: "#ec4899" },
};

// Generate a small QR for each recent item (vary encoding lengths)
const TH_SIZE = 150;

function contentForType(type, label) {
  switch (type) {
    case "url":   return "https://" + label;
    case "email": return "mailto:" + label;
    case "tel":   return "tel:" + label.replace(/\s/g, "");
    case "vcard": return `BEGIN:VCARD\nFN:${label}\nEND:VCARD`;
    case "wifi":  return `WIFI:T:WPA;S:${label.replace(/^Wi-Fi[: ]+/, "")};P:demo;;`;
    case "ical":  return `BEGIN:VEVENT\nSUMMARY:${label}\nDTSTART:20250615T140000Z\nEND:VEVENT`;
    default:      return label;
  }
}

// Main QR (the current one)
const MAIN_QR_SIZE = 440;
const MAIN_QR_CARD_W = MAIN_QR_SIZE + 60;
const MAIN_QR_CARD_X = CONTENT.x + 60;
const MAIN_QR_CARD_Y = CONTENT.y + 160;

const mainQr = renderQR({
  content: "https://radicalsolution.com/radical-qr",
  size: MAIN_QR_SIZE,
  roundness: 0.35,
  eyeRoundness: 1.0,
  eyeScale: 0.88,
  gradient: { start: MAC_COLORS.qrGradientStart, end: MAC_COLORS.qrGradientEnd, angle: 135 },
  background: "#ffffff",
  errorCorrection: "M",
  gradientId: "histMainQr",
});

// Right side: a column showing the "Recent" strip stacked vertically-ish
// We'll show 6 thumbnails in a 3×2 grid
const GRID_X = MAIN_QR_CARD_X + MAIN_QR_CARD_W + 60;
const GRID_Y = CONTENT.y + 200;
const GRID_COLS = 3;
const GRID_GAP_X = 48;
const GRID_GAP_Y = 64;

function renderThumbnail(idx, item) {
  const col = idx % GRID_COLS;
  const row = Math.floor(idx / GRID_COLS);
  const x = GRID_X + col * (TH_SIZE + GRID_GAP_X);
  const y = GRID_Y + row * (TH_SIZE + 50 + GRID_GAP_Y);
  const palette = TYPE_COLORS[item.type] ?? TYPE_COLORS.url;

  const qr = renderQR({
    content: contentForType(item.type, item.label),
    size: TH_SIZE - 24,
    roundness: 0.3,
    eyeRoundness: 1.0,
    eyeScale: 0.85,
    gradient: { start: palette.start, end: palette.end, angle: 135 },
    background: "#ffffff",
    errorCorrection: "M",
    gradientId: `th${idx}`,
  });

  return `
    <g filter="url(#macCardShadow)">
      <rect x="${x}" y="${y}" width="${TH_SIZE}" height="${TH_SIZE}" rx="14" ry="14" fill="#ffffff"/>
      <g transform="translate(${x + 12} ${y + 12})">${qr}</g>
    </g>
    <text x="${x}" y="${y + TH_SIZE + 28}" font-size="17" font-weight="500" fill="#ffffff" font-family="${MAC_FONT}">${escapeXML(item.label.slice(0, 18))}${item.label.length > 18 ? "…" : ""}</text>
  `;
}

// iCloud sync indicator
const ICLOUD_X = GRID_X;
const ICLOUD_Y = CONTENT.y + 100;

const inner = `
  ${macHeadline(L.headline)}

  ${macWindowShell({ activeSidebar: "history", proBadge: true })}

  <!-- Gradient content pane -->
  <path d="M ${CONTENT.x} ${CONTENT.y}
           H ${CONTENT.x + CONTENT.w - WINDOW.radius}
           a ${WINDOW.radius} ${WINDOW.radius} 0 0 1 ${WINDOW.radius} ${WINDOW.radius}
           V ${CONTENT.y + CONTENT.h - WINDOW.radius}
           a ${WINDOW.radius} ${WINDOW.radius} 0 0 1 ${-WINDOW.radius} ${WINDOW.radius}
           H ${CONTENT.x} Z" fill="url(#macScreenG)"/>

  <!-- App header -->
  <text x="${CONTENT.x + 44}" y="${CONTENT.y + 70}" font-size="36" font-weight="600" fill="#ffffff" font-family="${MAC_FONT}">${escapeXML(L.recent)}</text>

  <!-- iCloud indicator (top right of the pane) -->
  <g>
    <rect x="${ICLOUD_X + (TH_SIZE * 3 + GRID_GAP_X * 2) - 220}" y="${ICLOUD_Y - 36}" width="220" height="44" rx="22" ry="22" fill="#ffffff" opacity="0.2"/>
    <!-- cloud icon -->
    <path d="M ${ICLOUD_X + (TH_SIZE * 3 + GRID_GAP_X * 2) - 190} ${ICLOUD_Y - 12}
             a 10 10 0 0 1 -2 -18
             a 14 14 0 0 1 28 -4
             a 10 10 0 0 1 0 22 Z"
          fill="#ffffff"/>
    <text x="${ICLOUD_X + (TH_SIZE * 3 + GRID_GAP_X * 2) - 160}" y="${ICLOUD_Y - 8}" font-size="16" font-weight="600" fill="#ffffff" font-family="${MAC_FONT}">iCloud · synced</text>
  </g>

  <!-- Current QR card (the "featured" one) -->
  <g filter="url(#macCardShadow)">
    <rect x="${MAIN_QR_CARD_X}" y="${MAIN_QR_CARD_Y}" width="${MAIN_QR_CARD_W}" height="${MAIN_QR_SIZE + 60}" rx="20" ry="20" fill="#ffffff"/>
    <g transform="translate(${MAIN_QR_CARD_X + 30} ${MAIN_QR_CARD_Y + 30})">${mainQr}</g>
  </g>
  <text x="${MAIN_QR_CARD_X + MAIN_QR_CARD_W / 2}" y="${MAIN_QR_CARD_Y + MAIN_QR_SIZE + 110}" text-anchor="middle" font-size="20" font-weight="600" fill="#ffffff" font-family="${MAC_FONT}">radicalsolution.com/radical-qr</text>

  <!-- Recent strip (grid) -->
  ${L.items.map((item, i) => renderThumbnail(i, item)).join("")}

  ${macSubtitle(L.subtitle)}
`;

fs.mkdirSync(OUT, { recursive: true });
const filename = `m04-history-mac-${LOCALE}.svg`;
fs.writeFileSync(path.join(OUT, filename), macShell(inner));
console.log("wrote", path.relative(process.cwd(), path.join(OUT, filename)));
