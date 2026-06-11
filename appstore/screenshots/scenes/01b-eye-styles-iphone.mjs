/**
 * 01b-eye-styles-iphone.mjs — App Store screenshot: the 4 eye styles (1290×2796).
 * A 2×2 gallery of QR cards, each finder-pattern ("eye") in a different style.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { renderQR } from "../lib/qr-svg.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.resolve(__dirname, "../out");
const LOCALE = process.argv[2] || "en-US";

const COPY = {
  "en-US": { headline: ["Make the eyes", "your own."], subtitle: "Square · Rounded · Dot · Leaf" },
  "fr-FR": { headline: ["Des yeux", "à votre image."], subtitle: "Carré · Arrondi · Point · Feuille" },
};
const L = COPY[LOCALE] ?? COPY["en-US"];

const W = 1290, H = 2796;
const BG_START = "#667eea", BG_END = "#764ba2";
const QR_GRADIENT = { start: "#4D33D9", end: "#8C3BBF", angle: 135 };
const FONT = `-apple-system, 'SF Pro Display', sans-serif`;

const STYLES = [
  { style: "square",  label: { "en-US": "Square",  "fr-FR": "Carré" },   pro: false },
  { style: "rounded", label: { "en-US": "Rounded", "fr-FR": "Arrondi" }, pro: false },
  { style: "dot",     label: { "en-US": "Dot",     "fr-FR": "Point" },   pro: true  },
  { style: "leaf",    label: { "en-US": "Leaf",    "fr-FR": "Feuille" }, pro: true  },
];

// Grid layout
const CARD_W = 560, CARD_H = 660, GAP = 60;
const GRID_X = (W - (CARD_W * 2 + GAP)) / 2;
const GRID_Y = 760;
const QR_SIZE = 400;

function proPill(x, y) {
  return `<g>
    <rect x="${x - 46}" y="${y - 30}" width="92" height="46" rx="23" fill="#ffb800"/>
    <text x="${x}" y="${y + 2}" text-anchor="middle" font-size="26" font-weight="800" fill="#3a2a00" font-family="${FONT}">PRO</text>
  </g>`;
}

function card(col, row, item) {
  const x = GRID_X + col * (CARD_W + GAP);
  const y = GRID_Y + row * (CARD_H + GAP);
  const qr = renderQR({
    content: "https://radicalsolution.com",
    size: QR_SIZE,
    roundness: 0.3,
    eyeStyle: item.style,
    gradient: QR_GRADIENT,
    gradientId: `qr-${item.style}`,
  });
  const qx = x + (CARD_W - QR_SIZE) / 2;
  const qy = y + 70;
  return `<g>
    <rect x="${x}" y="${y}" width="${CARD_W}" height="${CARD_H}" rx="44" fill="#ffffff"/>
    <g transform="translate(${qx},${qy})">${qr}</g>
    <text x="${x + CARD_W / 2}" y="${y + CARD_H - 70}" text-anchor="middle" font-size="46" font-weight="700" fill="#1c1a17" font-family="${FONT}">${item.label[LOCALE] ?? item.label["en-US"]}</text>
    ${item.pro ? proPill(x + CARD_W - 70, y + 64) : ""}
  </g>`;
}

const cards = STYLES.map((s, i) => card(i % 2, Math.floor(i / 2), s)).join("\n");

const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="${BG_START}"/><stop offset="1" stop-color="${BG_END}"/>
    </linearGradient>
  </defs>
  <rect width="${W}" height="${H}" fill="url(#bg)"/>
  <g text-anchor="middle" font-family="${FONT}" fill="#ffffff">
    <text x="${W / 2}" y="360" font-size="120" font-weight="800">${esc(L.headline[0])}</text>
    <text x="${W / 2}" y="500" font-size="120" font-weight="800">${esc(L.headline[1])}</text>
  </g>
  ${cards}
  <text x="${W / 2}" y="${H - 150}" text-anchor="middle" font-size="52" font-weight="500" fill="#ffffff" opacity="0.95" font-family="${FONT}">${esc(L.subtitle)}</text>
</svg>
`;

fs.mkdirSync(OUT, { recursive: true });
const filename = `01b-eye-styles-iphone-6.9-${LOCALE}.svg`;
fs.writeFileSync(path.join(OUT, filename), svg);
console.log("wrote", filename);

function esc(s) { return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"); }
