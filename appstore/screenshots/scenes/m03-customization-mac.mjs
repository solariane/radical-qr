/**
 * m03-customization-mac.mjs — options that draw themselves, on the Mac.
 *
 * The scene this replaces still drew "Sharp / Slight / Rounded / Circular" as
 * text capsules; 2.0 deleted those. The tiles now come from `app-ui.mjs`, the
 * same code that draws them on the phone, so this screenshot cannot drift from
 * the app without someone noticing.
 */

import { renderQR } from "../lib/qr-svg.mjs";
import { copyFor } from "../lib/copy.mjs";
import { writeScene } from "../lib/poster.mjs";
import {
  MAC_CANVAS, MAC_POINTS, MAC_DETAIL, MAC_SIDEBAR_W, MAC_GUTTER,
  macWindow, macWindowRect, macSidebar, macShell, macHeadline, macSubtitle, macSignature,
} from "../lib/mac-frame.mjs";
import { generatorScreen } from "../lib/screens.mjs";
import {
  fittingMetrics, settingTile, moduleShapeGlyph, eyeShapeGlyph,
} from "../lib/app-ui.mjs";

const LOCALE = process.argv[2] || "en-US";
const L = copyFor("customization", LOCALE);

/**
 * The detail pane is wide and short, so `GeneratorMetrics.fitting` returns the
 * `split` preset: the settings sit beside the code rather than under it.
 */
const M = fittingMetrics(MAC_DETAIL.w, MAC_POINTS.h);

/** Shifted left, so the tile column gets a real margin rather than the edge. */
const WIN = macWindowRect({ w: 1780, x: 120, y: 235 });

/**
 * The tiles at poster size, in the margin beside the window. The Mac canvas is
 * landscape, so there is room down the right-hand side that the portrait posters
 * do not have — and a column of eight reads as a palette rather than a row.
 */
function tileColumn() {
  const side = 104;
  const gap = 18;
  const x = WIN.x + WIN.w + (MAC_CANVAS.w - WIN.x - WIN.w - side) / 2;
  const items = [
    ...[0, 0.3, 0.6, 1.0].map((step) => ({
      selected: step === 0.6,
      draw: (gx, gy, s) => moduleShapeGlyph(gx, gy, s, step),
    })),
    ...["square", "rounded", "dot", "leaf"].map((style) => ({
      selected: style === "leaf",
      draw: (gx, gy, s) => eyeShapeGlyph(gx, gy, s, style),
    })),
  ];
  const total = items.length * side + (items.length - 1) * gap;
  const y0 = WIN.y + (WIN.h - total) / 2;

  return `<g>${items.map((item, i) => settingTile({
    x, y: y0 + (side + gap) * i, w: side, h: side,
    selected: item.selected, content: item.draw,
  })).join("")}</g>`;
}

const qr = renderQR({
  content: "https://radicalsolution.com/radical-qr",
  size: M.preview, roundness: 1.0, eyeStyle: "dot", eyeScale: 1.0,
  gradient: { start: "#3B82F6", end: "#38C8D5", angle: 135 },
  errorCorrection: "M", gradientId: "macCustomQR",
});

const body = `
  ${macSidebar({ copy: L, active: "generator" })}
  ${generatorScreen({
    points: { w: MAC_DETAIL.w, h: MAC_POINTS.h },
    safeTop: 10, safeBottom: 10, gutter: MAC_GUTTER, originX: MAC_SIDEBAR_W,
    copy: L, family: "color",
    familyOptions: { selection: { gradient: 1, background: "white" } },
    qr, previewSize: M.preview, m: M,
    kind: L.kindURL, content: "radicalsolution.com/radical-qr",
  })}
`;

writeScene("m03-customization-mac", LOCALE, macShell(`
  ${macHeadline(L.headline)}
  ${macWindow(body, WIN)}
  ${tileColumn()}
  ${macSubtitle(L.subtitle, { y: WIN.y + WIN.h + 110 })}
  ${macSignature(L)}
`, WIN));
