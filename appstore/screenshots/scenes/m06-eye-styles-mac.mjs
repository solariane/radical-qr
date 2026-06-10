/**
 * m06-eye-styles-mac.mjs — App Store screenshot: the 4 eye styles (2880×1800).
 * A row of 4 QR cards, each finder-pattern ("eye") in a different style.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { renderQR } from "../lib/qr-svg.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.resolve(__dirname, "../out");
const LOCALE = process.argv[2] || "en-US";

const COPY = {
  "en-US": { headline: "Make the eyes your own.", subtitle: "Four finder-pattern styles — Square and Rounded free, Dot and Leaf with Pro." },
  "fr-FR": { headline: "Des yeux à votre image.", subtitle: "Quatre styles d’yeux — Carré et Arrondi gratuits, Point et Feuille avec Pro." },
};
const L = COPY[LOCALE] ?? COPY["en-US"];

const W = 2880, H = 1800;
const BG_START = "#667eea", BG_END = "#764ba2";
const QR_GRADIENT = { start: "#4D33D9", end: "#8C3BBF", angle: 135 };
const FONT = `-apple-system, 'SF Pro Display', 'Helvetica Neue', sans-serif`;

const STYLES = [
  { style: "square",  label: { "en-US": "Square",  "fr-FR": "Carré" },   pro: false },
  { style: "rounded", label: { "en-US": "Rounded", "fr-FR": "Arrondi" }, pro: false },
  { style: "dot",     label: { "en-US": "Dot",     "fr-FR": "Point" },   pro: true  },
  { style: "leaf",    label: { "en-US": "Leaf",    "fr-FR": "Feuille" }, pro: true  },
];

const CARD_W = 560, CARD_H = 720, GAP = 80;
const ROW_X = (W - (CARD_W * 4 + GAP * 3)) / 2;
const ROW_Y = 560;
const QR_SIZE = 420;

function proPill(x, y) {
  return `<g>
    <rect x="${x - 48}" y="${y - 30}" width="96" height="46" rx="23" fill="#ffb800"/>
    <text x="${x}" y="${y + 2}" text-anchor="middle" font-size="26" font-weight="800" fill="#3a2a00" font-family="${FONT}">PRO</text>
  </g>`;
}

function card(i, item) {
  const x = ROW_X + i * (CARD_W + GAP);
  const y = ROW_Y;
  const qr = renderQR({
    content: "https://radicalsolution.com",
    size: QR_SIZE,
    roundness: 0.3,
    eyeStyle: item.style,
    gradient: QR_GRADIENT,
    gradientId: `qr-${item.style}`,
  });
  const qx = x + (CARD_W - QR_SIZE) / 2;
  const qy = y + 80;
  return `<g>
    <rect x="${x}" y="${y}" width="${CARD_W}" height="${CARD_H}" rx="48" fill="#ffffff"/>
    <g transform="translate(${qx},${qy})">${qr}</g>
    <text x="${x + CARD_W / 2}" y="${y + CARD_H - 78}" text-anchor="middle" font-size="50" font-weight="700" fill="#1c1a17" font-family="${FONT}">${item.label[LOCALE] ?? item.label["en-US"]}</text>
    ${item.pro ? proPill(x + CARD_W - 76, y + 72) : ""}
  </g>`;
}

const cards = STYLES.map((s, i) => card(i, s)).join("\n");

const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="${BG_START}"/><stop offset="1" stop-color="${BG_END}"/>
    </linearGradient>
  </defs>
  <rect width="${W}" height="${H}" fill="url(#bg)"/>
  <text x="${W / 2}" y="320" text-anchor="middle" font-size="130" font-weight="800" fill="#ffffff" font-family="${FONT}">${esc(L.headline)}</text>
  ${cards}
  <text x="${W / 2}" y="${H - 150}" text-anchor="middle" font-size="52" font-weight="500" fill="#ffffff" opacity="0.95" font-family="${FONT}">${esc(L.subtitle)}</text>
</svg>
`;

fs.mkdirSync(OUT, { recursive: true });
const filename = `m06-eye-styles-mac-${LOCALE}.svg`;
fs.writeFileSync(path.join(OUT, filename), svg);
console.log("wrote", filename);

function esc(s) { return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"); }
