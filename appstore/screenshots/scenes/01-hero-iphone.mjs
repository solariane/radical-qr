/**
 * 01-hero-iphone.mjs — the first thing anyone sees on the listing.
 *
 * It draws the 2.0 generator as it actually is: the app mark and name in the
 * header, the preview card with its content pill, the five-family icon rail with
 * `shape` open, and the pinned Save row. Every size below is a point value
 * copied from `GeneratorMetrics.regular`, so the mockup and the app cannot drift
 * apart without someone editing both.
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
  METRICS as M, header, previewCard, familyRail, panel, actionRow,
  rowLabel, settingTile, moduleShapeGlyph, eyeShapeGlyph, eyeScaleGlyph,
} from "../lib/app-ui.mjs";

const LOCALE = process.argv[2] || "en-US";
const L = copyFor("hero", LOCALE);

// --- The app screen, in points ---------------------------------------------

const headerY = SAFE_TOP + M.sectionGap;
const previewY = headerY + M.headerHeight + M.sectionGap;
const previewH = M.cardPadding * 2 + (M.preview + 12) + M.rowGap + 30;
const railY = previewY + previewH + M.sectionGap;
const panelY = railY + M.railHeight + M.sectionGap;
const actionY = POINTS.h - SAFE_BOTTOM - M.sectionGap - M.actionHeight;

const qr = renderQR({
  content: "https://radicalsolution.com/radical-qr",
  size: M.preview,
  roundness: 0.6,
  eyeStyle: "leaf",
  eyeScale: 0.9,
  gradient: { start: "#4D33D9", end: "#8C3BBF", angle: 135 },
  background: null,
  errorCorrection: "M",
  gradientId: "heroQR",
});

/** The shape family, open — the row set that 2.0 replaced with drawn options. */
function shapePanel() {
  const x = GUTTER + M.panelPadding;
  const rowHeight = 13 + M.labelGap + M.tile;
  const rows = [
    {
      label: L.labelModules,
      tiles: [0, 0.3, 0.6, 1.0].map((step) => ({
        selected: step === 0.6,
        draw: (gx, gy, side) => moduleShapeGlyph(gx, gy, side, step),
      })),
    },
    {
      label: L.labelEyes,
      tiles: ["square", "rounded", "dot", "leaf"].map((style) => ({
        // No padlocks here: the hero sells the app, not the tier. The lock is
        // shown where it earns its place — the export scene.
        selected: style === "leaf",
        draw: (gx, gy, side) => eyeShapeGlyph(gx, gy, side, style),
      })),
    },
    {
      label: L.labelEyeSize,
      tiles: [0.75, 0.9, 1.0].map((step) => ({
        selected: step === 0.9,
        draw: (gx, gy, side) => eyeScaleGlyph(gx, gy, side, step),
      })),
    },
  ];

  const body = rows.map((row, index) => {
    const top = panelY + M.panelPadding + index * (rowHeight + M.rowGap);
    const tiles = row.tiles.map((tile, i) => settingTile({
      x: x + (M.tile + M.tileGap) * i,
      y: top + 13 + M.labelGap,
      selected: tile.selected,
      locked: Boolean(tile.locked) && !tile.selected,
      content: tile.draw,
    })).join("");
    return `${rowLabel(x, top + 9, row.label)}${tiles}`;
  }).join("");

  const height = M.panelPadding * 2 + rowHeight * 3 + M.rowGap * 2;
  return panel(GUTTER, panelY, CONTENT_W, height, body);
}

const screen = `
  ${header({ x: GUTTER, y: headerY, width: CONTENT_W })}
  ${previewCard({
    x: GUTTER, y: previewY, width: CONTENT_W,
    qr, previewSize: M.preview,
    kind: L.kindURL, content: "radicalsolution.com/radical-qr",
  })}
  ${familyRail({ x: GUTTER, y: railY, width: CONTENT_W, active: "shape" })}
  ${shapePanel()}
  ${actionRow({ x: GUTTER, y: actionY, width: CONTENT_W, label: L.save })}
`;

// --- Poster ----------------------------------------------------------------

const inner = `
  ${headlineBlock(L.headline)}
  ${badgeRow(L.badges, CANVAS.w / 2, 570)}
  ${phoneScreen(screen)}
  ${subtitleBlock(L.subtitle, { y: PHONE.y + PHONE.h + 150 })}
  ${signatureBlock(L)}
`;

writeScene("01-hero-iphone-6.9", LOCALE, svgShell(inner, screenDefs()));
