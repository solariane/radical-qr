/**
 * 02-launch-iphone.mjs — the screen you meet with nothing to encode.
 *
 * This one sells the promise the subtitle makes ("Auto-detect"): the user never
 * picks a format. So it draws `LaunchCard` exactly — dashed target, embedded
 * field, and the three capsules content actually arrives through, with Duplicate
 * in the middle where 2.0 put it — then the Pro recents strip and the privacy
 * note, in the order `GeneratorView` stacks them.
 */

import { copyFor } from "../lib/copy.mjs";
import { writeScene } from "../lib/poster.mjs";
import {
  PHONE, headlineBlock, subtitleBlock, svgShell,
  phoneScreen, screenDefs, signatureBlock,
  SAFE_TOP, GUTTER, CONTENT_W,
} from "../lib/phone-frame.mjs";
import {
  METRICS as M, header, launchCard, launchCardMetrics, recentStrip, inlineNote,
} from "../lib/app-ui.mjs";
import { renderQR } from "../lib/qr-svg.mjs";

const LOCALE = process.argv[2] || "en-US";
const L = copyFor("launch", LOCALE);
const P = copyFor("privacy", LOCALE);
const H = copyFor("history", LOCALE);

const headerY = SAFE_TOP + M.sectionGap;
const cardY = headerY + M.headerHeight + M.sectionGap;
const stripY = cardY + launchCardMetrics(L, CONTENT_W).height + M.sectionGap;

/** Four real payloads, so the strip shows four different codes as the app does. */
const RECENTS = [
  { label: "radicalsolution.com", content: "https://radicalsolution.com", roundness: 0.6, eyeStyle: "leaf", eyeScale: 0.9, gradient: { start: "#4D33D9", end: "#8C3BBF", angle: 135 } },
  { label: "Wi-Fi — Studio", content: "WIFI:T:WPA;S:Studio;P:radical2026;;", roundness: 0.3, eyeStyle: "rounded", color: "#1E3A5F" },
  { label: "Nicolas Lescure", content: "BEGIN:VCARD\nVERSION:3.0\nN:Lescure;Nicolas\nEND:VCARD", roundness: 1, eyeStyle: "dot", gradient: { start: "#3B82F6", end: "#38C8D5", angle: 135 } },
  { label: "Menu — Le Verre", content: "https://leverre.example/menu", roundness: 0, eyeStyle: "square", color: "#722F37" },
];

const recents = recentStrip({
  x: GUTTER, y: stripY, width: CONTENT_W, label: H.recent,
  items: RECENTS.map((item, i) => ({
    label: item.label,
    qr: renderQR({ ...item, size: 52, quietZone: 0, errorCorrection: "M", gradientId: `recent${i}` }),
  })),
});

const screen = `
  ${header({ x: GUTTER, y: headerY, width: CONTENT_W })}
  ${launchCard({ x: GUTTER, y: cardY, width: CONTENT_W, copy: L })}
  ${recents.svg}
  ${inlineNote({
    centerX: GUTTER + CONTENT_W / 2,
    y: stripY + recents.height + M.sectionGap + 12,
    label: P.note,
  })}
`;

const inner = `
  ${headlineBlock(L.headline)}
  ${phoneScreen(screen)}
  ${subtitleBlock(L.subtitle, { y: PHONE.y + PHONE.h + 150 })}
  ${signatureBlock(L)}
`;

writeScene("02-launch-iphone-6.9", LOCALE, svgShell(inner, screenDefs()));
