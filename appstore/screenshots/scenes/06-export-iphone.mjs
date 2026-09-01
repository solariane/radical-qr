/**
 * 06-export-iphone.mjs — sizes and formats, the fifth family.
 *
 * It draws a Pro screen — 4096 px and SVG selected, nothing padlocked — because
 * that is a real screen for anyone who has bought the upgrade, and a poster full
 * of padlocks sells nothing. What stops it being a half-truth is the subtitle,
 * which says plainly that this is the paid tier: one purchase, no subscription.
 */

import { renderQR } from "../lib/qr-svg.mjs";
import { copyFor } from "../lib/copy.mjs";
import { badgeRow, writeScene } from "../lib/poster.mjs";
import {
  CANVAS, PHONE, headlineBlock, subtitleBlock, svgShell,
  phoneScreen, screenDefs, signatureBlock,
  POINTS, SAFE_TOP, SAFE_BOTTOM, GUTTER, CONTENT_W,
} from "../lib/phone-frame.mjs";
import {
  METRICS as M, header, previewCard, familyRail, actionRow, exportFamily,
} from "../lib/app-ui.mjs";

const LOCALE = process.argv[2] || "en-US";
const L = copyFor("export", LOCALE);

const headerY = SAFE_TOP + M.sectionGap;
const previewY = headerY + M.headerHeight + M.sectionGap;
const previewH = M.cardPadding * 2 + (M.preview + 12) + M.rowGap + 30;
const railY = previewY + previewH + M.sectionGap;
const panelY = railY + M.railHeight + M.sectionGap;
const actionY = POINTS.h - SAFE_BOTTOM - M.sectionGap - M.actionHeight;

const qr = renderQR({
  content: "https://radicalsolution.com/radical-qr",
  size: M.preview,
  roundness: 0.3,
  eyeStyle: "rounded",
  eyeScale: 0.9,
  gradient: { start: "#F97316", end: "#EC4E8D", angle: 135 },
  errorCorrection: "M",
  gradientId: "exportQR",
});

const exports = exportFamily({
  x: GUTTER, y: panelY, width: CONTENT_W, copy: L,
  selection: { size: "4096", format: "SVG", isPro: true },
});

const screen = `
  ${header({ x: GUTTER, y: headerY, width: CONTENT_W })}
  ${previewCard({
    x: GUTTER, y: previewY, width: CONTENT_W,
    qr, previewSize: M.preview,
    kind: L.kindURL, content: "radicalsolution.com/radical-qr",
  })}
  ${familyRail({ x: GUTTER, y: railY, width: CONTENT_W, active: "export" })}
  ${exports.svg}
  ${actionRow({ x: GUTTER, y: actionY, width: CONTENT_W, label: L.save })}
`;

const inner = `
  ${headlineBlock(L.headline)}
  ${badgeRow(L.formats.slice(-3), CANVAS.w / 2, 578)}
  ${phoneScreen(screen)}
  ${subtitleBlock(L.subtitle, { y: PHONE.y + PHONE.h + 150 })}
  ${signatureBlock(L)}
`;

writeScene("06-export-iphone-6.9", LOCALE, svgShell(inner, screenDefs()));
