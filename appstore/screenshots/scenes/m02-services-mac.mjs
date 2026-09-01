/**
 * m02-services-mac.mjs — the Mac-only argument.
 *
 * `Info.plist` declares an `NSServices` entry handled by `ServicesProvider`, so
 * any selected text, link, vCard or .ics in any app can become a code without
 * opening Radical QR first. That is worth a whole screenshot on macOS and means
 * nothing on iPhone — which is why this scene has no portrait counterpart.
 */

import { renderQR } from "../lib/qr-svg.mjs";
import { copyFor } from "../lib/copy.mjs";
import { writeScene } from "../lib/poster.mjs";
import {
  MAC_CANVAS, MAC_FONT, MAC_COLORS, trafficLights,
  macShell, macHeadline, macSubtitle, macSignature, macEscape,
} from "../lib/mac-frame.mjs";
import { INK, text, appMark } from "../lib/app-ui.mjs";
import { symbol } from "../lib/symbols.mjs";

const LOCALE = process.argv[2] || "en-US";
const L = copyFor("services", LOCALE);

// --- The other app's document ----------------------------------------------

const DOC = { x: 210, y: 300, w: 1560, h: 900, radius: 18 };

/** A plain text document with one line selected — any app would do. */
function document() {
  const lines = [
    { text: "Radical Solution — press kit", weight: 700, size: 40 },
    { text: "", size: 20 },
    { text: "Everything about the 2.0 release, including the", size: 30 },
    { text: "icon set and the press images, lives here:", size: 30 },
    { text: L.selection, size: 30, selected: true },
    { text: "", size: 20 },
    { text: "Ask before republishing the screenshots.", size: 30, muted: true },
  ];

  let y = DOC.y + 110;
  const body = lines.map((line) => {
    y += line.size * 1.9;
    if (!line.text) return "";
    const width = line.text.length * line.size * 0.5;
    const highlight = line.selected
      ? `<rect x="${DOC.x + 62}" y="${y - line.size * 0.95}" width="${width}" height="${line.size * 1.35}" rx="4" fill="#B4D5FE"/>`
      : "";
    return `${highlight}${text(DOC.x + 64, y, line.text, {
      size: line.size, weight: line.weight ?? 400, family: MAC_FONT,
      fill: line.muted ? "#8A8A90" : "#1C1C20",
    })}`;
  }).join("");

  return `<g filter="url(#macWindowShadow)">
    <rect x="${DOC.x}" y="${DOC.y}" width="${DOC.w}" height="${DOC.h}" rx="${DOC.radius}" fill="#FFFFFF"/>
    <rect x="${DOC.x}" y="${DOC.y}" width="${DOC.w}" height="72" rx="${DOC.radius}" fill="#EDEDF1"/>
    <rect x="${DOC.x}" y="${DOC.y + 50}" width="${DOC.w}" height="22" fill="#EDEDF1"/>
    ${trafficLights(DOC.x + 30, DOC.y + 36).replace(/r="6"/g, 'r="10"')}
    ${body}
  </g>`;
}

// --- The context menu ------------------------------------------------------

const MENU = { x: DOC.x + 640, y: DOC.y + 560, w: 400, rowH: 62 };

/** Cut / Copy / Paste, then Services with its submenu open on our entry. */
function contextMenu() {
  const items = ["Cut", "Copy", "Paste"];
  const height = MENU.rowH * (items.length + 1) + 30;
  const servicesY = MENU.y + 14 + MENU.rowH * items.length + 10;

  const rows = items.map((item, i) => text(
    MENU.x + 34, MENU.y + 14 + MENU.rowH * i + MENU.rowH / 2 + 11, item,
    { size: 32, family: MAC_FONT, fill: "#8A8A90" }
  )).join("");

  const sub = { x: MENU.x + MENU.w - 12, y: servicesY - 6, w: 470, h: 92 };

  return `<g filter="url(#macCardShadow)">
    <rect x="${MENU.x}" y="${MENU.y}" width="${MENU.w}" height="${height}" rx="12" fill="#F7F7FA"/>
    ${rows}
    <rect x="${MENU.x + 8}" y="${servicesY - 8}" width="${MENU.w - 16}" height="${MENU.rowH}" rx="7" fill="${INK.accent}"/>
    ${text(MENU.x + 34, servicesY + MENU.rowH / 2 + 3, L.menuTitle, {
      size: 32, weight: 500, family: MAC_FONT, fill: "#ffffff",
    })}
    ${symbol("chevron", MENU.x + MENU.w - 36, servicesY + MENU.rowH / 2 - 8, 22, "#ffffff", "semibold")}

    <rect x="${sub.x}" y="${sub.y}" width="${sub.w}" height="${sub.h}" rx="12" fill="#F7F7FA"/>
    <rect x="${sub.x + 8}" y="${sub.y + 10}" width="${sub.w - 16}" height="${MENU.rowH}" rx="7" fill="${INK.accent}"/>
    ${appMark(sub.x + 26, sub.y + 10 + MENU.rowH / 2 - 17, 34, "#ffffff")}
    ${text(sub.x + 76, sub.y + 10 + MENU.rowH / 2 + 11, L.menuItem, {
      size: 30, weight: 500, family: MAC_FONT, fill: "#ffffff",
    })}
  </g>`;
}

// --- What comes out --------------------------------------------------------

const qr = renderQR({
  content: L.selection,
  size: 380,
  roundness: 0.6,
  eyeStyle: "leaf",
  eyeScale: 0.9,
  gradient: { start: "#4D33D9", end: "#8C3BBF", angle: 135 },
  errorCorrection: "M",
  gradientId: "servicesQR",
});

function result() {
  const size = 380;
  const x = MAC_CANVAS.w - size - 300;
  const y = DOC.y + 190;
  return `<g filter="url(#macCardShadow)">
    <rect x="${x - 46}" y="${y - 46}" width="${size + 92}" height="${size + 148}" rx="34" fill="#ffffff"/>
    <g transform="translate(${x} ${y})">${qr}</g>
    <text x="${x + size / 2}" y="${y + size + 68}" text-anchor="middle" font-family="${MAC_FONT}"
      font-size="34" font-weight="600" fill="${INK.railActive}">${macEscape(L.readyLabel)}</text>
  </g>`;
}

writeScene("m02-services-mac", LOCALE, macShell(`
  ${macHeadline(L.headline)}
  ${document()}
  ${contextMenu()}
  ${result()}
  ${macSubtitle(L.subtitle, { y: DOC.y + DOC.h + 130 })}
  ${macSignature(L)}
`));
